# -*- coding: utf-8 -*-
"""
AI 對話角色：預設老師、使用者自訂角色，以及腔調的解鎖判斷。

規則：
  - 「預設老師」免費，維持原本的家教模式。
  - 自訂角色：花 200 點新增（校園教育版學生沒有點數，免費新增），存在 custom_character 表；對話時人設會放進 AI 的指令。
  - 每新增一個自訂角色，可以解鎖「一種」腔調（新增時選，或之後再選；選了不能換）。
    解鎖的腔調之後和任何角色對話都能用，刪掉角色也不會收回；標準語永遠免費。
  - 新增過自訂角色就能用男聲。
  - 腔調名額不另外開表：用 PointTransaction.related_feature 當憑證，
    格式是 'custom_character:<角色 ID>'，選好腔調後變成 'custom_character:<角色 ID>:dialect:<腔調 ID>'。
    （舊版曾有付費官方角色，憑證是 'character:<角色 ID>...'，一樣算一個名額）
"""
from flask import Blueprint, request, jsonify
from sqlalchemy import or_
from models import db, User, PointTransaction, TransactionType, Dialect, CustomCharacter
from utils.account_helper import is_payment_free

character_bp = Blueprint('character', __name__)

STANDARD_JP_NAME = '標準語'   # 標準語免費，不佔腔調名額

CUSTOM_CHARACTER_COST = 200


def custom_character_cost(user):
    """新增一個自訂角色要花的點數；校園教育版學生免費（仍留一筆 0 點的紀錄當腔調名額憑證）"""
    return 0 if is_payment_free(user) else CUSTOM_CHARACTER_COST
_CUSTOM_FEATURE_PREFIX = 'custom_character:'
_LEGACY_FEATURE_PREFIX = 'character:'

# 自訂角色各欄位：(欄位, 中文名稱, 長度上限)
_CUSTOM_FIELDS = [
    ('name', '姓名', 50),
    ('origin', '出身地', 50),
    ('age', '年紀', 10),
    ('gender', '性別', 10),
    ('personality', '個性', 100),
    ('special_traits', '特殊設定', 200),
]

DEFAULT_CHARACTER = {
    'id': 'default_teacher',
    'name': '預設老師',
    'role': '親切耐心，標準日語',
    'origin': '東京',
    'age': '30',
    'gender': '女',
    'personality': '溫柔、有耐心、發音標準',
    'special_traits': '專業的日語教師，會糾正文法錯誤',
    'owned': True,
}


def _slot_rows(user_id):
    """每一筆代表一個腔調名額（新增自訂角色的扣點紀錄）"""
    if not user_id:
        return []
    return (PointTransaction.query
            .filter(PointTransaction.user_id == user_id,
                    or_(PointTransaction.related_feature.like(_CUSTOM_FEATURE_PREFIX + '%'),
                        PointTransaction.related_feature.like(_LEGACY_FEATURE_PREFIX + '%')))
            .order_by(PointTransaction.id)
            .all())


def _chosen_dialect(row):
    """名額憑證 → 已選的腔調 ID，還沒選回傳 None"""
    parts = row.related_feature.split(':')
    if len(parts) >= 4 and parts[2] == 'dialect' and parts[3].isdigit():
        return int(parts[3])
    return None


def unlocked_dialect_ids(user_id):
    """使用者已解鎖的腔調 ID"""
    return {d for d in (_chosen_dialect(r) for r in _slot_rows(user_id)) if d is not None}


def free_dialect_slots(user_id):
    """新增了角色但還沒選腔調的名額數"""
    return sum(1 for r in _slot_rows(user_id) if _chosen_dialect(r) is None)


def can_use_dialect(user_id, dialect_id):
    """這個腔調是不是使用者已解鎖的"""
    return dialect_id in unlocked_dialect_ids(user_id)


def _selectable_dialect(dialect_id):
    """可以拿來解鎖的腔調（啟用中、不是免費的標準語）；不符合回傳 None"""
    try:
        dialect = Dialect.query.filter_by(id=int(dialect_id), is_active=True).first()
    except (TypeError, ValueError):
        return None
    if dialect is None or dialect.jp_name == STANDARD_JP_NAME:
        return None
    return dialect


def _status(user_id):
    slots = _slot_rows(user_id)
    return {
        'unlocked_dialect_ids': sorted(unlocked_dialect_ids(user_id)),
        'free_dialect_slots': sum(1 for r in slots if _chosen_dialect(r) is None),
        # 新增過自訂角色：可以用男聲，也代表有（或有過）腔調名額
        'dialect_unlocked': bool(slots),
    }


def _custom_to_dict(c):
    return {
        'custom_id': c.id,
        'name': c.name,
        'role': '自訂角色',
        'origin': c.origin or '',
        'age': c.age or '',
        'gender': c.gender or '',
        'personality': c.personality or '',
        'special_traits': c.special_traits or '',
        'owned': True,
    }


def character_persona(user_id, name):
    """對話時用：依角色名字找出自己的自訂角色人設；
    找不到或是預設老師（照原本的家教模式）就回傳 None"""
    name = (name or '').strip()
    if not name or not user_id or name == DEFAULT_CHARACTER['name']:
        return None
    custom = CustomCharacter.query.filter_by(user_id=user_id, name=name).first()
    return _custom_to_dict(custom) if custom else None


@character_bp.route('/list', methods=['GET'])
def list_characters():
    """角色清單（預設老師＋自己的自訂角色），以及已解鎖的腔調與還沒用掉的腔調名額"""
    user_id = request.args.get('user_id', type=int)
    customs = (CustomCharacter.query.filter_by(user_id=user_id).order_by(CustomCharacter.id).all()
               if user_id else [])
    return jsonify({
        'characters': [DEFAULT_CHARACTER],
        'custom_characters': [_custom_to_dict(c) for c in customs],
        'custom_character_cost': custom_character_cost(User.query.get(user_id) if user_id else None),
        **_status(user_id),
    }), 200


@character_bp.route('/custom/create', methods=['POST'])
def create_custom_character():
    """花點數新增自訂角色（六個欄位都必填，同一位使用者的角色不可重名），
    可順便帶 dialect_id 解鎖一種腔調；沒帶就先保留名額，之後再選"""
    try:
        data = request.get_json(silent=True) or {}
        user_id = data.get('user_id')
        if not user_id:
            return jsonify({"error": "缺少使用者 ID"}), 400

        values = {}
        for field, label, limit in _CUSTOM_FIELDS:
            value = str(data.get(field) or '').strip()
            if not value:
                return jsonify({"error": f"請填寫{label}"}), 400
            if len(value) > limit:
                return jsonify({"error": f"{label}最多 {limit} 個字"}), 400
            values[field] = value

        if values['name'] == DEFAULT_CHARACTER['name'] or \
                CustomCharacter.query.filter_by(user_id=user_id, name=values['name']).first():
            return jsonify({"error": "已經有同名的角色了，請換個名字"}), 400

        dialect = None
        if data.get('dialect_id') not in (None, ''):
            dialect = _selectable_dialect(data.get('dialect_id'))
            if dialect is None:
                return jsonify({"error": "找不到這個腔調"}), 400
            if dialect.id in unlocked_dialect_ids(user_id):
                return jsonify({"error": "這個腔調已經解鎖過了，請選別的"}), 400

        user = User.query.get(user_id)
        if not user:
            return jsonify({"error": "找不到此使用者"}), 404
        cost = custom_character_cost(user)
        if (user.j_pts or 0) < cost:
            return jsonify({"error": f"點數不足，需要 {cost} 點"}), 400

        character = CustomCharacter(user_id=user_id, **values)
        db.session.add(character)
        db.session.flush()
        feature = f'{_CUSTOM_FEATURE_PREFIX}{character.id}'   # 同時是腔調名額的憑證
        if dialect is not None:
            feature += f':dialect:{dialect.id}'
        user.j_pts = (user.j_pts or 0) - cost
        db.session.add(PointTransaction(
            user_id=user_id,
            points=-cost,
            price=0,
            payment_method='points',
            transaction_type=TransactionType.SPEND,
            related_feature=feature,
        ))
        db.session.commit()

        unlocked_msg = f"，已解鎖「{dialect.name}」" if dialect else ""
        return jsonify({
            "message": f"已新增角色「{character.name}」{unlocked_msg}！",
            "total_points": user.j_pts,
            "character": _custom_to_dict(character),
            **_status(user_id),
        }), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({"error": f"[server error] {type(e).__name__}: {e}"}), 500


@character_bp.route('/custom/delete', methods=['POST'])
def delete_custom_character():
    """刪除自己的自訂角色（不退點數，已解鎖的腔調保留）"""
    data = request.get_json(silent=True) or {}
    user_id = data.get('user_id')
    character = CustomCharacter.query.filter_by(id=data.get('custom_id'), user_id=user_id).first() \
        if user_id else None
    if character is None:
        return jsonify({"error": "找不到這個角色"}), 404
    db.session.delete(character)
    db.session.commit()
    return jsonify({"message": f"已刪除角色「{character.name}」"}), 200


@character_bp.route('/choose_dialect', methods=['POST'])
def choose_dialect():
    """用新增角色得到、還沒用掉的名額解鎖一種腔調（不扣點，選了不能換）"""
    try:
        data = request.get_json(silent=True) or {}
        user_id = data.get('user_id')
        dialect = _selectable_dialect(data.get('dialect_id'))
        if not user_id or dialect is None:
            return jsonify({"error": "缺少使用者 ID 或找不到這個腔調"}), 400
        if dialect.id in unlocked_dialect_ids(user_id):
            return jsonify({"error": "這個腔調已經解鎖過了"}), 400

        row = next((r for r in _slot_rows(user_id) if _chosen_dialect(r) is None), None)
        if row is None:
            return jsonify({"error": "沒有可用的腔調名額，每新增一個自訂角色可以解鎖一種腔調"}), 400

        row.related_feature = f'{row.related_feature}:dialect:{dialect.id}'
        db.session.commit()
        return jsonify({"message": f"已解鎖「{dialect.name}」", **_status(user_id)}), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({"error": f"[server error] {type(e).__name__}: {e}"}), 500
