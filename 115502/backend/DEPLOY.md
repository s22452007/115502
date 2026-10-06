# 後端部署說明（Docker + MySQL + Cloudflare Tunnel）

本後端已 Docker 化，一鍵即可啟動；資料庫用 MySQL 8，API 與後台用 gunicorn 啟動；並可用 Cloudflare Tunnel 對外（免公網 IP、免開防火牆、免網域）。

## 需要準備
- 安裝 **Docker Desktop**（Windows 需 WSL2）或伺服器上的 **Docker Engine**
- `backend/.env`：複製 `.env.example` 改名，填好
  - Gemini 金鑰：`GEMINI_API_KEY`、`GEMINI_API_KEY_camara`（或各功能專用金鑰）
  - MySQL 密碼：`MYSQL_PASSWORD`、`MYSQL_ROOT_PASSWORD`（沒填 `docker compose up` 會直接停下來提示）
- 資料庫放在 Docker volume `mysql_data`、照片放 `backend/static/photos/`，容器重建不會遺失

## 服務組成
| 服務 | Port | 說明 |
|---|---|---|
| `mysql` | 3306（只開給本機） | MySQL 8.4，utf8mb4 |
| `api` | 5050 | 主 API（手機 App 連這個），gunicorn 啟動 |
| `admin` | 5001 | 後台管理網頁，gunicorn 啟動 |
| `cloudflared` | — | Cloudflare 通道（預設不啟動，見下） |

## 常用指令（都在 `backend/` 資料夾下執行）

```bash
# 本機 / 伺服器：跑 mysql + api + admin（不對外）
docker compose up -d --build

# 看狀態 / log / 停止（資料庫資料不會刪）
docker compose ps
docker compose logs -f api
docker compose down

# 對外公開（多啟動 cloudflared 通道）
docker compose --profile tunnel up -d

# 取得公開網址（找 trycloudflare.com 那行）
docker compose logs cloudflared

# 建立預設管理員帳號（第一次、或全新資料庫時）
docker compose exec api python init_admins.py
```

## 從 SQLite 搬到 MySQL（既有資料只做一次）
伺服器上原本有 `instance/jlens.db` 的資料要帶過去時：
1. 先只啟動 MySQL：`docker compose up -d mysql`
2. 在伺服器主機（或任何能連到 3306 的電腦）執行搬資料腳本：
   ```bash
   py -3 migrate_sqlite_to_mysql.py --to "mysql+pymysql://jlens:<MYSQL_PASSWORD>@127.0.0.1:3306/jlens?charset=utf8mb4"
   ```
   腳本會建表、逐表複製（保留 id）、標記遷移版本、核對每張表的筆數。VARCHAR 內容超過模型長度的會列出來；
   想截斷就加 `--truncate`，想重搬就加 `--force`（會先清空目標）。
3. 再啟動其他服務：`docker compose up -d --build`。照片檔 `static/photos/` 直接複製即可，資料庫只存檔名。

全新伺服器（沒有舊資料）不用這步，`docker compose up -d --build` 啟動時會自動建表、種預設資料。

## 資料表結構有改（models.py）時
```bash
py -3 -m flask --app app db migrate -m "說明這次改了什麼"
```
產生 `migrations/versions/xxxx_說明.py`，檢查內容後跟 `models.py` 一起 commit。
組員 pull 後、伺服器 `docker compose up -d` 後，啟動時會自動套用，不用手動下指令。詳見 `migrations/README`。

## 組員本機開發
- 不設 `DATABASE_URL` 就是 SQLite（`instance/jlens.db`），`python app.py`、`python admin_app.py` 照舊，不用裝 MySQL。
- 想在本機也用 MySQL：`docker compose up -d mysql`，然後在 `.env` 加
  `DATABASE_URL=mysql+pymysql://jlens:<MYSQL_PASSWORD>@127.0.0.1:3306/jlens?charset=utf8mb4`。
- gunicorn 只在 Docker 裡用（Windows 跑不起來），本機開發仍是 Flask 開發伺服器。

## 上學校伺服器（最終目標）
1. 伺服器裝好 Docker
2. `git clone` 專案 → `cd backend`
3. 建立 `backend/.env`（貼入 Gemini 金鑰、設定 MySQL 密碼）
4. 有舊資料就先照「從 SQLite 搬到 MySQL」做；沒有就直接下一步
5. `docker compose --profile tunnel up -d --build`
6. `docker compose exec api python init_admins.py` 建管理員（全新資料庫時）
7. 取得公開網址、更新 App `baseUrl`（`jpn_learning_app/lib/utils/api_client.dart`），重新 build App

## 備份
```bash
# 匯出整個資料庫（建議排程每天跑一次，檔案另外存到別台機器）
docker compose exec mysql sh -c 'mysqldump -ujlens -p"$MYSQL_PASSWORD" jlens' > backup_$(date +%F).sql
# 還原
docker compose exec -T mysql sh -c 'mysql -ujlens -p"$MYSQL_PASSWORD" jlens' < backup_2026-10-06.sql
```

## 注意事項
- **Quick Tunnel 的網址是臨時的**：每次重啟 `cloudflared` 會換一組新網址。要固定網址需準備一個網域，改用「Named Tunnel」。
- `docker compose down -v` 會連 MySQL 資料一起刪，平常不要加 `-v`。
- `.env` 裡的 `DATABASE_URL` 只給本機直接跑 Python 用；容器內的 api / admin 固定連 `mysql` 服務，不受影響。
- gunicorn 的 worker 數預設 2，伺服器核心多可在 `.env` 設 `WEB_CONCURRENCY`；AI 請求逾時放寬到 180 秒（`gunicorn.conf.py`）。
- 正式對外前建議在 `.env` 設 `SECRET_KEY`（App 登入通行證）與 `ADMIN_SECRET_KEY`（後台登入），並把 `DEMO_PAYMENT=off`。
