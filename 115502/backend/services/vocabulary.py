from flask import Blueprint, request, jsonify

from utils.db import db
from models import UserVocab, UserFolder

vocab_bp = Blueprint('vocab', __name__)

# 取得單字本資料夾
@vocab_bp.route('/favorites/<int:user_id>', methods=['GET'])
def get_user_favorites(user_id):
    user_vocabs = UserVocab.query.filter_by(user_id=user_id).all()
    folders = {}

    # 1. 抓取系統單字自動生成的資料夾
    for uv in user_vocabs:
        scene_name = uv.vocab.scene.name if uv.vocab.scene else "未分類單字"
        if scene_name not in folders:
            folders[scene_name] = {"name": scene_name, "count": 0}
        folders[scene_name]["count"] += 1

    # 2. 去資料庫抓取使用者「自訂」的資料夾
    custom_folders = UserFolder.query.filter_by(user_id=user_id).all()
    for cf in custom_folders:
        if cf.name not in folders:
            folders[cf.name] = {"name": cf.name, "count": 0}

    result = list(folders.values())
    return jsonify({"favorites": result}), 200

# 建立自訂資料夾
@vocab_bp.route('/folders', methods=['POST'])
def create_folder():
    data = request.get_json()
    user_id = data.get('user_id')
    name = data.get('name')

    if not user_id or not name:
        return jsonify({"error": "缺少必要資料"}), 400

    # 把自訂資料夾存進資料庫
    new_folder = UserFolder(user_id=user_id, name=name)
    db.session.add(new_folder)
    db.session.commit()

    return jsonify({"message": "資料夾建立成功！"}), 201
