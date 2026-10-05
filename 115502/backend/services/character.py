# -*- coding: utf-8 -*-
"""
AI 對話角色：官方角色清單、用點數購買角色、腔調選單的解鎖判斷。

規則：
  - 「預設老師」免費；其他官方角色要用 J-Pts 購買（買一次永久擁有）。
  - 每買一個官方角色，可以解鎖「一種」腔調（自己挑，選了不能換），300 點含角色與腔調。
    解鎖的腔調之後和任何角色、自訂角色對話都能用；標準語永遠免費。
  - 買過角色就能用男聲。
  - 買過沒有不另外開表：用 PointTransaction.related_feature 當憑證，
    格式是 'character:<角色 ID>'，選好腔調後變成 'character:<角色 ID>:dialect:<腔調 ID>'。
  - 自訂角色：花 200 點新增，存在 custom_character 表，不附腔調名額。
  - 對話時依角色名字找出人設（官方角色要已擁有、自訂角色要是自己的），放進 AI 的指令。
"""
from flask import Blueprint, request, jsonify
from models import db, User, PointTransaction, TransactionType, Dialect, CustomCharacter

character_bp = Blueprint('character', __name__)

STANDARD_JP_NAME = '標準語'   # 標準語免費，不佔腔調名額

CHARACTER_COST = 300
CUSTOM_CHARACTER_COST = 200
_FEATURE_PREFIX = 'character:'
_CUSTOM_FEATURE_PREFIX = 'custom_character:'

# 自訂角色各欄位：(欄位, 中文名稱, 長度上限)
_CUSTOM_FIELDS = [
    ('name', '姓名', 50),
    ('origin', '出身地', 50),
    ('age', '年紀', 10),
    ('gender', '性別', 10),
    ('personality', '個性', 100),
    ('special_traits', '特殊設定', 200),
]

# 官方角色（cost 為 0 代表免費）。要加新角色在這裡加一筆即可，App 會自動顯示。
OFFICIAL_CHARACTERS = [
    {
        'id': 'default_teacher',
        'name': '預設老師',
        'role': '親切耐心，標準日語',
        'origin': '東京',
        'age': '30',
        'gender': '女',
        'personality': '溫柔、有耐心、發音標準',
        'special_traits': '專業的日語教師，會糾正文法錯誤',
        'cost': 0,
    },
    {
        'id': 'seto_kei',
        'name': '瀨戶 景',
        'role': '隨性慵懶的貓奴貝斯手',
        'origin': '九州',
        'age': '23',
        'gender': '男',
        'personality': '1. 隨性慵懶 2. 對喜歡的事物充滿熱情 3. 說話帶點幽默感',
        'special_traits': '獨立樂團貝斯手、App開發者、重度貓奴',
        'cost': CHARACTER_COST,
    },
]


def _purchase_rows(user_id):
    if not user_id:
        return []
    return (PointTransaction.query
            .filter(PointTransaction.user_id == user_id,
                    PointTransaction.related_feature.like(_FEATURE_PREFIX + '%'))
            .order_by(PointTransaction.id)
            .all())


def _parse(row):
    """購買憑證 → (角色 ID, 已選的腔調 ID 或 None)"""
    parts = row.related_feature.split(':')
    dialect_id = int(parts[3]) if len(parts) >= 4 and parts[2] == 'dialect' and parts[3].isdigit() else None
    return parts[1], dialect_id


def owned_character_ids(user_id):
    """使用者買過的官方角色 ID"""
    return {_parse(r)[0] for r in _purchase_rows(user_id)}


def unlocked_dialect_ids(user_id):
    """使用者已解鎖的腔調 ID（每買一個角色可以解鎖一種）"""
    return {d for d in (_parse(r)[1] for r in _purchase_rows(user_id)) if d is not None}


def free_dialect_slots(user_id):
    """買了角色但還沒選腔調的名額數"""
    return sum(1 for r in _purchase_rows(user_id) if _parse(r)[1] is None)


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
    owned = owned_character_ids(user_id)
    return {
        'unlocked_dialect_ids': sorted(unlocked_dialect_ids(user_id)),
        'free_dialect_slots': free_dialect_slots(user_id),
        # 買過角色：可以用男聲，也代表有（或有過）腔調名額
        'dialect_unlocked': bool(owned),
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
    """對話時用：依角色名字找出人設。官方角色要已擁有、自訂角色要是自己的；
    找不到或是預設老師（照原本的家教模式）就回傳 None"""
    name = (name or '').strip()
    if not name:
        return None
    official = next((c for c in OFFICIAL_CHARACTERS if c['name'] == name), None)
    if official is not None:
        if official['cost'] == 0 or official['id'] not in owned_character_ids(user_id):
            return None
        return official
    if not user_id:
        return None
    custom = CustomCharacter.query.filter_by(user_id=user_id, name=name).first()
    return _custom_to_dict(custom) if custom else None


@character_bp.route('/list', methods=['GET'])
def list_characters():
    """官方角色清單（含是否已擁有）、自己的自訂角色，以及已解鎖的腔調與還沒用掉的腔調名額"""
    user_id = request.args.get('user_id', type=int)
    owned = owned_character_ids(user_id)
    customs = (CustomCharacter.query.filter_by(user_id=user_id).order_by(CustomCharacter.id).all()
               if user_id else [])
    return jsonify({
        'characters': [
            {**c, 'owned': c['cost'] == 0 or c['id'] in owned}
            for c in OFFICIAL_CHARACTERS
        ],
        'custom_characters': [_custom_to_dict(c) for c in customs],
        'custom_character_cost': CUSTOM_CHARACTER_COST,
        **_status(user_id),
    }), 200


@character_bp.route('/custom/create', methods=['POST'])
def create_custom_character():
    """花點數新增自訂角色（六個欄位都必填，同一位使用者的角色不可重名）"""
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

        if any(c['name'] == values['name'] for c in OFFICIAL_CHARACTERS) or \
                CustomCharacter.query.filter_by(user_id=user_id, name=values['name']).first():
            return jsonify({"error": "已經有同名的角色了，請換個名字"}), 400

        user = User.query.get(user_id)
        if not user:
            return jsonify({"error": "找不到此使用者"}), 404
        if user.j_pts < CUSTOM_CHARACTER_COST:
            return jsonify({"error": f"點數不足，需要 {CUSTOM_CHARACTER_COST} 點"}), 400

        character = CustomCharacter(user_id=user_id, **values)
        db.session.add(character)
        db.session.flush()
        user.j_pts -= CUSTOM_CHARACTER_COST
        db.session.add(PointTransaction(
            user_id=user_id,
            points=-CUSTOM_CHARACTER_COST,
            price=0,
            payment_method='points',
            transaction_type=TransactionType.SPEND,
            related_feature=f'{_CUSTOM_FEATURE_PREFIX}{character.id}',
        ))
        db.session.commit()

        return jsonify({
            "message": f"已新增角色「{character.name}」！",
            "total_points": user.j_pts,
            "character": _custom_to_dict(character),
        }), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({"error": f"[server error] {type(e).__name__}: {e}"}), 500


@character_bp.route('/custom/delete', methods=['POST'])
def delete_custom_character():
    """刪除自己的自訂角色（不退點數）"""
    data = request.get_json(silent=True) or {}
    user_id = data.get('user_id')
    character = CustomCharacter.query.filter_by(id=data.get('custom_id'), user_id=user_id).first() \
        if user_id else None
    if character is None:
        return jsonify({"error": "找不到這個角色"}), 404
    db.session.delete(character)
    db.session.commit()
    return jsonify({"message": f"已刪除角色「{character.name}」"}), 200


@character_bp.route('/buy', methods=['POST'])
def buy_character():
    """用點數購買官方角色，並解鎖一種腔調（dialect_id；沒帶就先保留名額，之後再選）"""
    try:
        data = request.get_json(silent=True) or {}
        user_id = data.get('user_id')
        character_id = data.get('character_id')
        dialect_id = data.get('dialect_id')

        character = next((c for c in OFFICIAL_CHARACTERS if c['id'] == character_id), None)
        if not user_id or character is None:
            return jsonify({"error": "缺少使用者 ID 或找不到此角色"}), 400
        if character['cost'] <= 0:
            return jsonify({"error": "這個角色不需要購買"}), 400

        user = User.query.get(user_id)
        if not user:
            return jsonify({"error": "找不到此使用者"}), 404

        if character_id in owned_character_ids(user_id):
            return jsonify({"error": "已經擁有這個角色了"}), 400

        dialect = None
        if dialect_id not in (None, ''):
            dialect = _selectable_dialect(dialect_id)
            if dialect is None:
                return jsonify({"error": "找不到這個腔調"}), 400
            if dialect.id in unlocked_dialect_ids(user_id):
                return jsonify({"error": "這個腔調已經解鎖過了，請選別的"}), 400

        if user.j_pts < character['cost']:
            return jsonify({"error": f"點數不足，需要 {character['cost']} 點"}), 400

        feature = _FEATURE_PREFIX + character_id   # 同時是「買過了」的憑證
        if dialect is not None:
            feature += f':dialect:{dialect.id}'
        user.j_pts -= character['cost']
        db.session.add(PointTransaction(
            user_id=user_id,
            points=-character['cost'],
            price=0,
            payment_method='points',
            transaction_type=TransactionType.SPEND,
            related_feature=feature,
        ))
        db.session.commit()

        unlocked_msg = f"已解鎖「{dialect.name}」" if dialect else "還可以選一種腔調解鎖"
        return jsonify({
            "message": f"成功購買「{character['name']}」！{unlocked_msg}",
            "total_points": user.j_pts,
            **_status(user_id),
        }), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({"error": f"[server error] {type(e).__name__}: {e}"}), 500


@character_bp.route('/choose_dialect', methods=['POST'])
def choose_dialect():
    """用買角色得到、還沒用掉的名額解鎖一種腔調（不扣點，選了不能換）"""
    try:
        data = request.get_json(silent=True) or {}
        user_id = data.get('user_id')
        dialect = _selectable_dialect(data.get('dialect_id'))
        if not user_id or dialect is None:
            return jsonify({"error": "缺少使用者 ID 或找不到這個腔調"}), 400
        if dialect.id in unlocked_dialect_ids(user_id):
            return jsonify({"error": "這個腔調已經解鎖過了"}), 400

        row = next((r for r in _purchase_rows(user_id) if _parse(r)[1] is None), None)
        if row is None:
            return jsonify({"error": "沒有可用的腔調名額，每購買一位角色可以解鎖一種腔調"}), 400

        row.related_feature = f'{row.related_feature}:dialect:{dialect.id}'
        db.session.commit()
        return jsonify({"message": f"已解鎖「{dialect.name}」", **_status(user_id)}), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({"error": f"[server error] {type(e).__name__}: {e}"}), 500
