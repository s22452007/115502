"""gunicorn 設定（Docker 裡的正式啟動方式；本機開發仍可直接 python app.py）

api：   gunicorn -c gunicorn.conf.py -b 0.0.0.0:5050 app:app
admin： gunicorn -c gunicorn.conf.py -b 0.0.0.0:5001 admin_app:app
"""
import multiprocessing
import os

# worker 數：預設 2，伺服器核心多可以在 .env 用 WEB_CONCURRENCY 調高；
# 每個 worker 再開多條執行緒，AI 請求在等 Gemini 回應時不會卡住其他人
workers = int(os.getenv('WEB_CONCURRENCY') or 2)
worker_class = 'gthread'
threads = int(os.getenv('GUNICORN_THREADS') or 4)

# Gemini 分析照片、朗讀評分可能要幾十秒，逾時放寬到 3 分鐘（預設 30 秒會把 AI 請求砍掉）
timeout = int(os.getenv('GUNICORN_TIMEOUT') or 180)
graceful_timeout = 30
keepalive = 5

# 經過 Cloudflare Tunnel 進來時，用 X-Forwarded-* 還原真實來源與 https
forwarded_allow_ips = '*'

# log 直接印到容器輸出（docker compose logs 看得到）
accesslog = '-'
errorlog = '-'
loglevel = os.getenv('GUNICORN_LOGLEVEL') or 'info'

# 不預載 app：每個 worker 自己載入並跑 utils/db.init_database（內含鎖，不會重複建表），
# 避免 fork 前就開了資料庫連線被多個 worker 共用
preload_app = False
