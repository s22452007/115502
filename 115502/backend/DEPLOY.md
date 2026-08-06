# 後端部署說明（Docker + Cloudflare Tunnel）

本後端已 Docker 化，一鍵即可啟動；並可用 Cloudflare Tunnel 對外（免公網 IP、免開防火牆、免網域）。

## 需要準備
- 安裝 **Docker Desktop**（Windows 需 WSL2）或伺服器上的 **Docker Engine**
- `backend/.env` 內要有 Gemini 金鑰：`GEMINI_API_KEY`、`GEMINI_API_KEY_camara`
- 資料庫（`backend/instance/jlens.db`）與照片（`backend/static/photos/`）會用 volume 掛載，容器重建不會遺失

## 服務組成
| 服務 | Port | 說明 |
|---|---|---|
| `api` | 5050 | 主 API（手機 App 連這個） |
| `admin` | 5001 | 後台管理網頁 |
| `cloudflared` | — | Cloudflare 通道（預設不啟動，見下） |

## 常用指令（都在 `backend/` 資料夾下執行）

```bash
# 本機開發：只跑 api + admin（不對外）
docker compose up -d --build

# 看狀態 / log / 停止
docker compose ps
docker compose logs -f
docker compose down

# 對外公開（多啟動 cloudflared 通道）
docker compose --profile tunnel up -d

# 取得公開網址（找 trycloudflare.com 那行）
docker compose logs cloudflared
```

## 對外流程
1. `docker compose --profile tunnel up -d`
2. `docker compose logs cloudflared` → 複製 `https://xxx.trycloudflare.com`
3. 把 App 的連線網址（`jpn_learning_app/lib/utils/api_client.dart` 的 `baseUrl`）改成該公開網址，重新 build App
4. 手機/任何裝置即可連線

## 上學校伺服器（最終目標）
1. 伺服器裝好 Docker
2. `git clone` 專案 → `cd backend`
3. 在伺服器建立 `backend/.env`（貼入 Gemini 金鑰）
4. `docker compose --profile tunnel up -d --build`
5. 取得公開網址、更新 App `baseUrl`

## 注意事項
- **Quick Tunnel 的網址是臨時的**：每次重啟 `cloudflared` 會換一組新網址。要固定網址需準備一個網域，改用「Named Tunnel」。
- 資料只存在執行的那台機器（volume）；換機器要一併搬 `instance/` 與 `static/photos/`。
- 目前資料庫為 SQLite；若改用 MySQL，於 compose 增加 mysql 服務並改 `app.py` 的連線字串即可（已預裝 PyMySQL）。
