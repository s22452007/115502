# Snap to Learn 日語學習 App — 後端程式架構與功能清單

本文件完整收錄 **Snap to Learn 日語學習 App** 後端服務（基於 Python Flask 與 SQLAlchemy 開發，位於 `backend/` 目錄）之所有程式檔案清單。內容依模組架構分類，詳列檔案名稱、相對路徑、功能名稱及其詳細功能說明，便於團隊開發、系統部署與維護查閱。

---

## 目錄
1. [專案目錄結構概覽](#專案目錄結構概覽)
2. [核心應用入口與資料模型 (Core Application & Models)](#一-核心應用入口與資料模型-core-application--models)
3. [業務邏輯與 API 服務模組 (Services Blueprint Modules)](#二-業務邏輯與-api-服務模組-services-blueprint-modules)
4. [核心工具與輔助函式庫 (Utilities & Helpers)](#三-核心工具與輔助函式庫-utilities--helpers)
5. [資料庫維護、遷移與種子資料 (Database & Migration Scripts)](#四-資料庫維護遷移與種子資料-database--migration-scripts)
6. [測試與驗證腳本 (Tests & Diagnostics)](#五-測試與驗證腳本-tests--diagnostics)

---

## 專案目錄結構概覽

```text
backend/
├── app.py                         # Flutter App 客戶端 API 服務進入點
├── admin_app.py                   # 系統後台管理系統與教師端 Web 服務
├── models.py                      # 全系統 SQLAlchemy 資料庫實體模型
├── services/                      # 各功能模組之 Blueprint 路由與業務邏輯
│   ├── auth.py                    # 登入、註冊、校園驗證與忘記密碼
│   ├── user.py                    # 個人檔案、等級晉階、好友關係
│   ├── scenario.py                # AI 照片情境辨識與主題圖鑑
│   ├── roleplay.py                # AI 角色扮演對話與即時反饋
│   ├── sentence.py                # AI 文法造句練習與評分
│   ├── article.py                 # 分級閱讀、振假名標音與測驗
│   ├── vocabulary.py              # 生詞庫、相簿分類資料夾
│   ├── tutor.py                   # AI 日語家教提問與解答
│   ├── classroom.py               # 學生端加入班級與班級名冊
│   ├── student_assignment.py      # 學生端作業檢視與作答交卷
│   ├── teacher_service.py         # 教師端班級出題、批閱與進度統計
│   ├── subscription.py            # VIP 訂閱方案與 Google Play 內購
│   ├── store.py                   # J-Points 點數包與生詞庫擴充槽商城
│   ├── group.py                   # 學習同好會（讀書會）與排行榜
│   ├── daily_reward.py            # 連續登入獎勵與每日任務打卡
│   ├── quiz.py                    # 日語等級快篩測驗
│   ├── dialect.py                 # 日本各地區方言轉換
│   ├── tts.py                     # 日語語音合成 (TTS)
│   └── chat_history.py            # 對話歷史紀錄管理
├── utils/                         # 通用工具庫、權限驗證與 AI 客戶端
├── templates/                     # 後台管理與教師端 HTML 樣板
└── static/                        # 後台靜態資源 (CSS, JS, 圖片)
```

---

## 一、 核心應用入口與資料模型 (Core Application & Models)

| 檔案名稱 | 檔案路徑 | 功能名稱 | 功能說明 |
| :--- | :--- | :--- | :--- |
| `app.py` | `backend/app.py` | App 後端主程式進入點 | 提供 Flutter App 連線之 RESTful API 服務核心。整合 CORS 跨域處理、全域錯誤處理、資料庫連線初始化，並掛載註冊各業務 Blueprint 模組。 |
| `admin_app.py` | `backend/admin_app.py` | 系統管理後台與教師端進入點 | 提供 Web 端管理介面與校園教師端系統。包含平台數據統計、單字庫管理、文章上下架、教師班級管理、作業指派出題與作業成績批閱系統。 |
| `models.py` | `backend/models.py` | 全系統資料庫模型定義 | 集中定義所有 SQLAlchemy ORM 模型（包含 `User`, `Classroom`, `ClassroomMember`, `Assignment`, `AssignmentSubmission`, `Article`, `Scenario`, `Vocabulary`, `StudyGroup`, `Subscription` 等）。 |

---

## 二、 業務邏輯與 API 服務模組 (Services Blueprint Modules)

| 檔案名稱 | 檔案路徑 | 功能名稱 | 功能說明 |
| :--- | :--- | :--- | :--- |
| `auth.py` | `backend/services/auth.py` | 身分驗證與授權服務 | 處理使用者一般註冊、密碼雜湊檢查、JWT 簽發登入、忘記密碼驗證信，以及學校 edu.tw 郵件驗證碼認證登入。 |
| `user.py` | `backend/services/user.py` | 使用者核心資料服務 | 查詢與更新個人檔案、頭像變更、重設密碼、五維能力雷達圖數據統計、日語等級晉階判定與好友管理（發送/接受好友邀請、好友名單）。 |
| `scenario.py` | `backend/services/scenario.py` | AI 影像情境辨識服務 | 接收相機拍照或相簿上傳之圖片，呼叫 Gemini AI 進行場景辨識、物件標籤萃取、相關日語生詞推薦、情境自然度判定與主題圖鑑收集。 |
| `roleplay.py` | `backend/services/roleplay.py` | AI 角色扮演對話服務 | 根據特定情境設定 AI 扮演角色（如超商店員、居酒屋老闆），支援語音/文字多輪交談，並即時給予對話修正建議。 |
| `sentence.py` | `backend/services/sentence.py` | AI 文法造句練習服務 | 針對使用者輸入之日語造句進行 AI 語法診斷，提供精準文法說明、道地修正建議與百分制評分。 |
| `article.py` | `backend/services/article.py` | 日語分級閱讀服務 | 依 N1~N5 提供分級閱讀文章、自動生成日文漢字振假名 (Furigana) 標音、單字釋義解析與文章閱讀測驗評分結算。 |
| `vocabulary.py` | `backend/services/vocabulary.py` | 生詞庫與相簿管理服務 | 負責單字生詞的收藏/取消、自訂分類資料夾 (Folder) 的 CRUD、依照片分組檢視生詞及生詞庫上限容量控制。 |
| `tutor.py` | `backend/services/tutor.py` | AI 日語家教服務 | 提供 24 小時線上 AI 日語家教諮詢，針對使用者的日語文法、語感差異或檢定疑問提供深度解答與例句。 |
| `classroom.py` | `backend/services/classroom.py` | 學生端班級管理服務 | 供學生在 App 端輸入 6 碼班級隨機碼加入班級、檢視自己已加入的班級列表與教師指派資訊。 |
| `student_assignment.py` | `backend/services/student_assignment.py` | 學生端作業繳交服務 | 查詢班級待完成與已完成作業清單、提交造句挑戰作業、作答文章指定閱讀測驗與查閱教師評語。 |
| `teacher_service.py` | `backend/services/teacher_service.py` | 教師端教學管理核心邏輯 | 教師專屬業務模組：包含班級建立、隨機碼生成/重新生成、造句與文章出題、全班學習狀況統計、學生作答批閱與評分給分。 |
| `subscription.py` | `backend/services/subscription.py` | VIP 會員訂閱服務 | 管理訂閱方案（月繳/年繳）、7 天免費試用開通、Google Play 應用程式內購收據驗證、自動續訂狀態檢查與每月點數特權發放。 |
| `store.py` | `backend/services/store.py` | 商城與點數加購服務 | 提供 J-Points 儲值點數包購買、生詞庫擴充槽購買、金幣/點數扣除與消費交易明細紀錄。 |
| `group.py` | `backend/services/group.py` | 學習同好會 (讀書會) 服務 | 建立與加入學習同好會、每週共同學習目標設定、成員學習貢獻度結算與同好會積分排行榜。 |
| `daily_reward.py` | `backend/services/daily_reward.py` | 每日任務與登入獎勵服務 | 每日登入簽到打卡、連續學習天數 (Streak) 計算、每日拍照與對話任務達成驗證及點數發放。 |
| `quiz.py` | `backend/services/quiz.py` | 程度快篩與課堂測驗服務 | 提供初次使用者的日檢等級快速測驗題庫、答題檢查、算分與推薦日語檢定起點。 |
| `dialect.py` | `backend/services/dialect.py` | 日本方言轉換服務 | 將標準東京日語轉換為關西腔、博多腔等多種地區方言，提供道地對話例句與文化背景介紹。 |
| `tts.py` | `backend/services/tts.py` | 日語文字語音合成 (TTS) | 將日語單字、例句、文章與對話即時轉換為清晰標準的日語語音音訊檔案或音訊串流。 |
| `chat_history.py` | `backend/services/chat_history.py` | 對話紀錄管理服務 | 查詢過往與 AI 角色扮演對話的完整歷史對話紀錄與學習足跡。 |

---

## 三、 核心工具與輔助函式庫 (Utilities & Helpers)

| 檔案名稱 | 檔案路徑 | 功能名稱 | 功能說明 |
| :--- | :--- | :--- | :--- |
| `db.py` | `backend/utils/db.py` | 資料庫連線實例 | 宣告 SQLAlchemy `db` 全域實例，負責資料庫連線池與交易生命週期管理。 |
| `jwt_helper.py` | `backend/utils/jwt_helper.py` | JWT 權杖工具 | 提供 JWT 產生、自訂 Payload 封裝、密鑰簽署與過期時間驗證函式。 |
| `auth_helper.py` | `backend/utils/auth_helper.py` | 身分驗證裝飾器 | 提供 `@jwt_required` 與權限檢查裝飾器，自動解析 HTTP Request Header 的 Bearer Token 並提取當前使用者實體。 |
| `account_helper.py` | `backend/utils/account_helper.py` | 帳號權限判斷工具 | 判斷使用者之帳號類型（一般用戶、校園教育版學生、教師端、超級管理員）與對應權限檢查。 |
| `feature_guard.py` | `backend/utils/feature_guard.py` | 功能權限守衛 | 檢查使用者當日剩餘免費拍照次數、AI 對話扣點邏輯，以及針對 VIP 會員與校園教育版學生的免扣點通行判定。 |
| `gemini_client.py` | `backend/utils/gemini_client.py` | Gemini AI 客戶端封裝 | 封裝 Google Gemini 官方 SDK，提供 Prompt 結構化設定、溫度參數調整、Token 消耗監控與錯誤重試機制。 |
| `ai_helper.py` | `backend/utils/ai_helper.py` | AI 輸出解析輔助 | 解析 AI 回傳的 Markdown / JSON 格式文字，自動清理 Markdown 程式碼標記並轉化為 Python Dict/List。 |
| `subscription_helper.py` | `backend/utils/subscription_helper.py` | 訂閱排程輔助 | 計算訂閱有效期限、判斷是否逾期、處理每日額度自動歸零與 VIP 每月獎勵自動入帳。 |
| `group_helper.py` | `backend/utils/group_helper.py` | 讀書會結算工具 | 計算同好會每週任務完成度、每位成員每週積分彙整與排行排序。 |

---

## 四、 資料庫維護、遷移與種子資料 (Database & Migration Scripts)

| 檔案名稱 | 檔案路徑 | 功能名稱 | 功能說明 |
| :--- | :--- | :--- | :--- |
| `upgrade_db.py` | `backend/upgrade_db.py` | 資料庫動態結構遷移腳本 | 自動檢測 SQLite / MySQL 欄位完整性，若缺少新增欄位（如校園版、新額度欄位）則自動執行 `ALTER TABLE` 補齊。 |
| `create_db.py` | `backend/create_db.py` | 資料庫結構初始化腳本 | 呼叫 `db.create_all()` 建立全新資料庫綱要與所有關聯資料表。 |
| `init_admins.py` | `backend/init_admins.py` | 預設管理員與教師初始化 | 建立系統預設超級管理員帳號及示範教師帳號，並設定安全雜湊密碼。 |
| `seed.py` | `backend/seed.py` | 基礎種子資料填充 | 填充系統初期基礎單字庫、情境類別、預設等級設定等初始數據。 |
| `seed_articles.py` | `backend/seed_articles.py` | 閱讀文章種子填充 | 批次寫入日語 N5~N1 分級閱讀文章、翻譯、漢字振假名與閱讀理解測驗題庫。 |
| `seed_themes.py` | `backend/seed_themes.py` | 主題圖鑑資料填充 | 寫入日本居酒屋、便利商店、觀光景點等主題圖鑑章節與預設單字群。 |
| `seed_demo_learning.py` | `backend/seed_demo_learning.py` | 學生示範學習歷程填充 | 填充示範學生之作業作答、造句紀錄與學習雷達圖數據，供展示報告使用。 |
| `upgrade_db_vocabs.py` | `backend/upgrade_db_vocabs.py` | 單字庫欄位結構升級 | 針對生詞表擴充音訊欄位、詞性與例句結構之升級維護腳本。 |
| `backfill_furigana.py` | `backend/backfill_furigana.py` | 假名標音歷史資料補全 | 為資料庫中過往未標註假名的文章或生詞自動補齊振假名資料。 |
| `backfill_vocab_translations.py` | `backend/backfill_vocab_translations.py` | 中文翻譯批次補全 | 批次補齊單字庫與例句中缺漏之繁體中文翻譯。 |
| `cleanup_duplicate_vocab.py` | `backend/cleanup_duplicate_vocab.py` | 重複單字清理工具 | 掃描資料庫中重複建立之單字資料並進行智慧整併與冗餘清除。 |
| `reset_extra.py` | `backend/reset_extra.py` | 每日額度重置排程測試 | 測試每日午夜定時將免費使用者的每日拍照次數與 AI 額度重置。 |
| `dev_unlock_theme.py` | `backend/dev_unlock_theme.py` | 開發者圖鑑解鎖測試 | 開發測試專用工具，快速解鎖所有主題圖鑑以驗證前端 UI 展示。 |
| `force_sync.py` | `backend/force_sync.py` | 資料強制同步腳本 | 強制將記憶體快取與實體資料庫狀態進行完全同步。 |

---

## 五、 測試與驗證腳本 (Tests & Diagnostics)

| 檔案名稱 | 檔案路徑 | 功能名稱 | 功能說明 |
| :--- | :--- | :--- | :--- |
| `test_routes.py` | `backend/test_routes.py` | 路由整合測試腳本 | 對後端所有公開與受保護 API 端點執行自動化 HTTP 狀態碼與回傳格式驗證。 |
| `test_models.py` | `backend/test_models.py` | ORM 資料模型單元測試 | 驗證各資料表之間的 Foreign Key 關聯、Cascade 刪除與約束條件。 |
| `test_gradebook.py` | `backend/test_gradebook.py` | 成績單與批閱邏輯測試 | 針對教師出題、學生繳交、AI 初評、教師手動評分及平均分數統計流程進行單元測試。 |
| `test_photo_chat_assignment.py` | `backend/test_photo_chat_assignment.py` | 拍照情境與作業全流程測試 | 模擬學生從拍照辨識、對話練習到完成課堂作業的完整端到端 (E2E) 流程。 |
| `test_gemini.py` | `backend/test_gemini.py` | Gemini AI 連通性診斷 | 檢查後端 `.env` 設定之 Google API 金鑰有效性與模型連線延遲狀況。 |
| `check_admin_db.py` | `backend/check_admin_db.py` | 管理員資料庫診斷工具 | 快速檢驗後台管理者與任課教師之登入帳號狀態與審核標記。 |
| `check_keys.py` | `backend/check_keys.py` | 金鑰與環境變數檢查 | 驗證後端運行必要環境變數（如 `JWT_SECRET`, `GEMINI_API_KEY`）是否完整設定。 |
