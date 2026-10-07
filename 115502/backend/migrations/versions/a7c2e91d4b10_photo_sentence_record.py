"""photo sentence record

拍照後「練習造句」的紀錄（含語法小教室內容），在「我的單字探險」照片詳情頁回顧。

Revision ID: a7c2e91d4b10
Revises: f3b1d264821d
Create Date: 2026-10-07 21:30:00

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'a7c2e91d4b10'
down_revision = 'f3b1d264821d'
branch_labels = None
depends_on = None


def upgrade():
    # 啟動時的安全網（ensure_model_columns / create_all）可能已經先建好這張表，有就跳過
    if 'photo_sentence_record' in sa.inspect(op.get_bind()).get_table_names():
        return
    op.create_table('photo_sentence_record',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('user_id', sa.Integer(), nullable=False),
    sa.Column('photo_id', sa.Integer(), nullable=True),
    sa.Column('sentence', sa.Text(), nullable=False),
    sa.Column('is_valid', sa.Boolean(), nullable=True),
    sa.Column('result', sa.JSON(), nullable=True),
    sa.Column('created_at', sa.DateTime(), nullable=True),
    sa.ForeignKeyConstraint(['photo_id'], ['user_photo.id'], ),
    sa.ForeignKeyConstraint(['user_id'], ['user.id'], ),
    sa.PrimaryKeyConstraint('id')
    )
    with op.batch_alter_table('photo_sentence_record', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_photo_sentence_record_photo_id'), ['photo_id'], unique=False)
        batch_op.create_index(batch_op.f('ix_photo_sentence_record_user_id'), ['user_id'], unique=False)


def downgrade():
    with op.batch_alter_table('photo_sentence_record', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_photo_sentence_record_user_id'))
        batch_op.drop_index(batch_op.f('ix_photo_sentence_record_photo_id'))

    op.drop_table('photo_sentence_record')
