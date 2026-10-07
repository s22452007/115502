"""school seat limit

學校合約名額 school.seat_limit（100 或 500 人），不可為空、預設 100。

Revision ID: b5d0e3a8c612
Revises: a7c2e91d4b10
Create Date: 2026-10-08 12:00:00

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'b5d0e3a8c612'
down_revision = 'a7c2e91d4b10'
branch_labels = None
depends_on = None


def upgrade():
    bind = op.get_bind()
    columns = {c['name'] for c in sa.inspect(bind).get_columns('school')}
    if 'seat_limit' not in columns:
        with op.batch_alter_table('school', schema=None) as batch_op:
            batch_op.add_column(sa.Column('seat_limit', sa.Integer(), nullable=False, server_default='100'))
        return

    # 啟動時的安全網（ensure_model_columns）可能已經先補了這個欄位，但當時沒有 NOT NULL：補值後改成不可為空
    op.execute('UPDATE school SET seat_limit = 100 WHERE seat_limit IS NULL')
    with op.batch_alter_table('school', schema=None) as batch_op:
        batch_op.alter_column('seat_limit', existing_type=sa.Integer(), nullable=False, server_default='100')


def downgrade():
    with op.batch_alter_table('school', schema=None) as batch_op:
        batch_op.drop_column('seat_limit')
