# Snap to Learn 日語學習 App — 前端程式架構與功能清單

本文件完整收錄 **Snap to Learn 日語學習 App** 前端（基於 Flutter 開發，位於 `jpn_learning_app/lib`）之所有程式檔案清單。內容依模組架構分類，詳列檔案路徑、功能名稱及其詳細功能說明，便於團隊開發、維護與專案報告查閱。

---

## 目錄
1. [專案目錄結構概覽](#專案目錄結構概覽)
2. [核心入口與狀態管理 (Core & Providers)](#一-核心入口與狀態管理-core--providers)
3. [身分驗證、校園認證與新手導引 (Auth & Onboarding)](#二-身分驗證校園認證與新手導引-auth--onboarding)
4. [首頁與主畫面儀表板 (Home & Navigation)](#三-首頁與主畫面儀表板-home--navigation)
5. [AI 相機拍照、情境辨識與對話練習 (Scenario & Camera)](#四-ai-相機拍照情境辨識與對話練習-scenario--camera)
6. [文法句型與 AI 造句挑戰 (Sentence Practice)](#五-文法句型與-ai-造句挑戰-sentence-practice)
7. [日語閱讀與文章朗讀 (Article Reading)](#六-日語閱讀與文章朗讀-article-reading)
8. [校園教育版與班級作業 (Edu & Classroom)](#七-校園教育版與班級作業-edu--classroom)
9. [AI 日語家教與提問 (AI Tutor)](#八-ai-日語家教與提問-ai-tutor)
10. [學習同好會與讀書會 (Study Group & Leaderboard)](#九-學習同好會與讀書會-study-group--leaderboard)
11. [好友社群與私訊 (Friends & Chat)](#十-好友社群與私訊-friends--chat)
12. [商城、點數購買與 VIP 訂閱 (Premium & Store)](#十一-商城點數購買與-vip-訂閱-premium--store)
13. [個人中心、生詞本與相簿資料夾 (Profile & Vocab Folders)](#十二-個人中心生詞本與相簿資料夾-profile--vocab-folders)
14. [服務層與 API 通訊 (Services & Utilities)](#十三-服務層與-api-通訊-services--utilities)
15. [資料模型層 (Data Models)](#十四-資料模型層-data-models)
16. [共用 UI 元件與彈窗 (Widgets & Dialogs)](#十五-共用-ui-元件與彈窗-widgets--dialogs)

---

## 專案目錄結構概覽

```text
jpn_learning_app/lib/
├── firebase_options.dart          # Firebase 設定
├── main.dart                      # 應用程式進入點
├── models/                        # 資料模型 (Data Models)
├── providers/                     # 狀態管理 (ChangeNotifier Providers)
├── screens/                       # 各功能頁面 (Screens / Pages)
│   ├── article/                   # 日語閱讀模組
│   ├── auth/                      # 登入、註冊、校園驗證與程度快篩
│   ├── edu/                       # 校園教育版、班級作業與測驗
│   ├── friends/                   # 好友清單、搜尋與即時聊天
│   ├── home/                      # 主頁儀表板
│   ├── leaderboard/               # 讀書會、每週任務與排行榜
│   ├── premium/                   # 商城、點數儲值與 VIP 訂閱
│   ├── profile/                   # 個人檔案、生詞庫相簿與設定
│   ├── scenario/                  # AI 相機、情境辨識與角色扮演對話
│   ├── sentence/                  # 文法造句挑戰與評分歷史
│   └── tutor/                     # AI 家教主頁與互動提問
├── services/                      # 商業邏輯與後端 API 呼叫服務
├── utils/                         # 工具函式、權限檢查與全域常數
└── widgets/                       # 共用 UI 元件、對話框與卡片
```

---

## 一、 核心入口與狀態管理 (Core & Providers)

| 檔案名稱 | 檔案路徑 | 功能名稱 | 功能說明 |
| :--- | :--- | :--- | :--- |
| `main.dart` | `lib/main.dart` | 應用程式進入點 | 初始化 App、設定全域 Provider、深色/淺色主題與全域路由管理。 |
| `firebase_options.dart` | `lib/firebase_options.dart` | Firebase 設定檔 | 各平台（Android / iOS / Web）Firebase 推播與雲端配置設定。 |
| `user_provider.dart` | `lib/providers/user_provider.dart` | 使用者狀態管理 | 管理當前登入者資訊、點數 (J-Points)、等級、訂閱會員身分與每日任務狀態。 |
| `auth_provider.dart` | `lib/providers/auth_provider.dart` | 身分驗證狀態 | 負責 Token 儲存、登入/登出狀態廣播與驗證生命週期維護。 |
| `scenario_provider.dart` | `lib/providers/scenario_provider.dart` | 情境學習狀態 | 管理目前辨識出的情境資料、延伸單字清單與對話狀態暫存。 |
| `font_size_provider.dart` | `lib/providers/font_size_provider.dart` | 字型縮放管理 | 提供 App 內部字體大小動態調整（大/中/小）的狀態控制。 |
| `favorites_data.dart` | `lib/providers/favorites_data.dart` | 收藏生詞狀態 | 集中管理使用者收藏的日文單字與片語清單。 |

---

## 二、 身分驗證、校園認證與新手導引 (Auth & Onboarding)

| 檔案名稱 | 檔案路徑 | 功能名稱 | 功能說明 |
| :--- | :--- | :--- | :--- |
| `splash_screen.dart` | `lib/screens/auth/splash_screen.dart` | 啟動載入畫面 | App 開啟時的載入頁，負責檢查本地 Token 與網路連線狀態。 |
| `welcome_screen.dart` | `lib/screens/auth/welcome_screen.dart` | 歡迎引導頁 | 初次安裝進入畫面，提供註冊、一般登入或校園入口選擇。 |
| `login_screen.dart` | `lib/screens/auth/login_screen.dart` | 一般帳號登入/註冊 | 支援 Email 密碼登入、新使用者註冊及輸入欄位防呆驗證。 |
| `edu_login_screen.dart` | `lib/screens/auth/edu_login_screen.dart` | 校園教育版登入驗證 | 提供學校 Email 驗證碼登入，自動辨識學校並加入教育版。 |
| `forgot_password_screen.dart` | `lib/screens/auth/forgot_password_screen.dart` | 忘記密碼 | 發送密碼重設驗證信至使用者註冊信箱。 |
| `onboarding_screen.dart` | `lib/screens/auth/onboarding_screen.dart` | 新手引導流程 | 初次登入的教學介紹與系統特色功能導覽。 |
| `level_select_screen.dart` | `lib/screens/auth/level_select_screen.dart` | 日語程度選擇頁 | 讓使用者自選日檢程度（N1 ~ N5）或進入快篩測驗。 |
| `quick_test_screen.dart` | `lib/screens/auth/quick_test_screen.dart` | 日語程度快篩測驗 | 提供初評測驗題庫，檢測使用者的實際日語水準。 |
| `test_result_screen.dart` | `lib/screens/auth/test_result_screen.dart` | 測驗結果判定頁 | 顯示快篩得分與建議設定的日語檢定等級。 |
| `privacy_policy_screen.dart` | `lib/screens/auth/privacy_policy_screen.dart` | 隱私權政策頁 | 顯示系統服務條款與使用者隱私權保護政策內容。 |

---

## 三、 首頁與主畫面儀表板 (Home & Navigation)

| 檔案名稱 | 檔案路徑 | 功能名稱 | 功能說明 |
| :--- | :--- | :--- | :--- |
| `intro_screen.dart` | `lib/screens/intro_screen.dart` | 主框架切換頁 | 封裝底部導覽列（BottomNavBar），負責切換各主功能分頁。 |
| `home_screen.dart` | `lib/screens/home/home_screen.dart` | 主頁儀表板 | 顯示每日任務、連續學習天數、快捷入口與最新情境輪播。 |

---

## 四、 AI 相機拍照、情境辨識與對話練習 (Scenario & Camera)

| 檔案名稱 | 檔案路徑 | 功能名稱 | 功能說明 |
| :--- | :--- | :--- | :--- |
| `camera_screen.dart` | `lib/screens/scenario/camera_screen.dart` | 智慧拍照相機 | 相機鏡頭取景、拍照、相簿選圖及前後鏡頭旋轉切換。 |
| `analyzing_screen.dart` | `lib/screens/scenario/analyzing_screen.dart` | AI 影像辨識載入頁 | 上傳照片並展示多步驟動態進度（場景分析、單字擷取）。 |
| `scene_result_screen.dart` | `lib/screens/scenario/scene_result_screen.dart` | 拍照分析結果頁 | 顯示辨識出場景、延伸單字、假名發音與例句推薦。 |
| `scenario_detail_screen.dart` | `lib/screens/scenario/scenario_detail_screen.dart` | 情境詳細頁面 | 深入學習該情境下的單字清單、語音朗讀與例句解釋。 |
| `role_play_intro_screen.dart` | `lib/screens/scenario/role_play_intro_screen.dart` | 情境對話導引頁 | 選擇角色扮演模式、目標任務與對話難度說明。 |
| `roleplay_screen.dart` | `lib/screens/scenario/roleplay_screen.dart` | AI 角色扮演對話頁 | 語音/文字與 AI 對話練習，支援即時翻譯與多種日本方言。 |
| `grammar_tip_screen.dart` | `lib/screens/scenario/grammar_tip_screen.dart` | 文法解析提點 | 針對情境句型與單字提供詳細的日文文法教學筆記。 |
| `naturalness_screen.dart` | `lib/screens/scenario/naturalness_screen.dart` | 自然度評分頁 | 針對學生所造句子進行道地程度與文法精確度診斷。 |
| `make_sentence_screen.dart` | `lib/screens/scenario/make_sentence_screen.dart` | 情境自選造句 | 讓使用者挑選情境中的單字進行造句並獲得 AI 批閱。 |
| `manual_search_screen.dart` | `lib/screens/scenario/manual_search_screen.dart` | 手動情境搜尋 | 若不拍照，可透過關鍵字文字搜尋對應之日語情境。 |
| `result_gallery_v2_screen.dart` | `lib/screens/scenario/result_gallery_v2_screen.dart` | 拍照歷史相簿 | 依時間軸瀏覽過往拍照分析過的照片及關聯單字庫。 |
| `history_menu_screen.dart` | `lib/screens/scenario/history_menu_screen.dart` | 歷史紀錄選單 | 統合查看拍照歷程、對話紀錄與造句清單入口。 |
| `chat_history_screen.dart` | `lib/screens/scenario/chat_history_screen.dart` | 對話紀錄複習 | 查閱過往與 AI 角色扮演的完整對話文字與錄音。 |
| `theme_collection_intro_screen.dart` | `lib/screens/scenario/theme_collection_intro_screen.dart` | 主題圖鑑介紹頁 | 日本文化、便利商店、居酒屋等特定主題圖鑑說明。 |
| `theme_collection_screen.dart` | `lib/screens/scenario/theme_collection_screen.dart` | 主題圖鑑收集冊 | 解鎖不同場景的蒐集進度與成就圖鑑徽章。 |

---

## 五、 文法句型與 AI 造句挑戰 (Sentence Practice)

| 檔案名稱 | 檔案路徑 | 功能名稱 | 功能說明 |
| :--- | :--- | :--- | :--- |
| `sentence_practice_screen.dart` | `lib/screens/sentence/sentence_practice_screen.dart` | AI 文法造句練習 | 依指定文法句型與規定單字進行造句，AI 即時評分與修訂。 |
| `sentence_history_screen.dart` | `lib/screens/sentence/sentence_history_screen.dart` | 造句練習歷史 | 瀏覽歷史造句作業或自主練習的評語、修訂對照與分數。 |

---

## 六、 日語閱讀與文章朗讀 (Article Reading)

| 檔案名稱 | 檔案路徑 | 功能名稱 | 功能說明 |
| :--- | :--- | :--- | :--- |
| `article_list_screen.dart` | `lib/screens/article/article_list_screen.dart` | 日語閱讀文章清單 | 依檢定級別 (N5~N1) 分類展示日語文章，支援搜尋與篩選。 |
| `article_detail_screen.dart` | `lib/screens/article/article_detail_screen.dart` | 文章詳細閱讀頁面 | 支援假名標音 (振假名)、單字點擊查義、語音朗讀與中日對照。 |
| `article_result_screen.dart` | `lib/screens/article/article_result_screen.dart` | 文章測驗結算頁 | 閱讀理解測驗完畢後的成績反饋與點數獎勵結算。 |
| `article_history_screen.dart` | `lib/screens/article/article_history_screen.dart` | 文章閱讀歷史 | 查看已讀文章紀錄、完成次數與學習時長統計。 |

---

## 七、 校園教育版與班級作業 (Edu & Classroom)

| 檔案名稱 | 檔案路徑 | 功能名稱 | 功能說明 |
| :--- | :--- | :--- | :--- |
| `classroom_list_screen.dart` | `lib/screens/edu/classroom_list_screen.dart` | 已加入班級列表 | 學生檢視已加入之班級名冊，並可輸入 6 位隨機碼加入新班級。 |
| `assignment_list_screen.dart` | `lib/screens/edu/assignment_list_screen.dart` | 班級作業清單 | 檢視待完成與已完成作業（造句作業、指定閱讀、測驗）。 |
| `assignment_detail_screen.dart` | `lib/screens/edu/assignment_detail_screen.dart` | 作業內容作答頁 | 作業詳情檢視、造句提交、老師評語與分數反饋查閱。 |
| `article_quiz_screen.dart` | `lib/screens/edu/article_quiz_screen.dart` | 老師指派測驗作答 | 文章閱讀配套之選擇題、是非題在線作答與交卷。 |

---

## 八、 AI 日語家教與提問 (AI Tutor)

| 檔案名稱 | 檔案路徑 | 功能名稱 | 功能說明 |
| :--- | :--- | :--- | :--- |
| `tutor_home_screen.dart` | `lib/screens/tutor/tutor_home_screen.dart` | AI 家教主頁面 | 顯示常見文法 FAQ、提問次數狀態與家教引導。 |
| `ask_question_screen.dart` | `lib/screens/tutor/ask_question_screen.dart` | 向家教提問輸入頁 | 輸入學習問題（文法、單字差異、句型）並向 AI 送出提問。 |
| `tutor_answer_screen.dart` | `lib/screens/tutor/tutor_answer_screen.dart` | 家教詳細解答頁面 | 呈現 AI 家教針對問題整理的詳細解析、例句與重點提示。 |

---

## 九、 學習同好會與讀書會 (Study Group & Leaderboard)

| 檔案名稱 | 檔案路徑 | 功能名稱 | 功能說明 |
| :--- | :--- | :--- | :--- |
| `study_group_home_screen.dart` | `lib/screens/leaderboard/study_group_home_screen.dart` | 同好會大廳 | 顯示已加入讀書會或建立/尋找新同好會入口。 |
| `study_group_screen.dart` | `lib/screens/leaderboard/study_group_screen.dart` | 讀書會成員與排行榜 | 顯示讀書會每週任務、成員積分排行榜與達標進度。 |
| `group_config_screen.dart` | `lib/screens/leaderboard/group_config_screen.dart` | 讀書會建立與設定 | 設定同好會名稱、每週目標、挑戰難度與人數上限。 |
| `invite_group_members_screen.dart` | `lib/screens/leaderboard/invite_group_members_screen.dart` | 邀請好友入會 | 從好友名單中挑選好友發送同好會邀請通知。 |
| `group_invites_screen.dart` | `lib/screens/leaderboard/group_invites_screen.dart` | 收到邀請列表 | 審核與接受其他好友傳送過來的讀書會邀請。 |

---

## 十、 好友社群與私訊 (Friends & Chat)

| 檔案名稱 | 檔案路徑 | 功能名稱 | 功能說明 |
| :--- | :--- | :--- | :--- |
| `myfriends_screen.dart` | `lib/screens/friends/myfriends_screen.dart` | 好友名單 | 顯示目前好友清單、上線狀態及待確認邀請。 |
| `addfriends_screen.dart` | `lib/screens/friends/addfriends_screen.dart` | 新增好友 | 透過專屬好友碼（Friend ID）或 Email 搜尋並發送好友請求。 |
| `chat_screen.dart` | `lib/screens/friends/chat_screen.dart` | 好友聊天室 | 好友一對一即時訊息傳送與學習心得交流。 |

---

## 十一、 商城、點數購買與 VIP 訂閱 (Premium & Store)

| 檔案名稱 | 檔案路徑 | 功能名稱 | 功能說明 |
| :--- | :--- | :--- | :--- |
| `store_dashboard_screen.dart` | `lib/screens/premium/store_dashboard_screen.dart` | 商城總覽儀表板 | 點數加購、VIP 會員方案、生詞庫擴充與道具兌換中心。 |
| `premium_trial_screen.dart` | `lib/screens/premium/premium_trial_screen.dart` | 免費試用方案 | 提供 7 天高級會員特權試用啟用流程與特權對比。 |
| `subscription_checkout_screen.dart` | `lib/screens/premium/subscription_checkout_screen.dart` | 訂閱結帳頁面 | 月繳/年繳 VIP 訂閱方案挑選與結帳頁面。 |
| `point_checkout_screen.dart` | `lib/screens/premium/point_checkout_screen.dart` | 點數加購結帳 | 挑選 J-Points 儲值點數包並前往付款。 |
| `credit_card_payment_screen.dart` | `lib/screens/premium/credit_card_payment_screen.dart` | 信用卡付款頁面 | 支援信用卡刷卡輸入卡號、到期日與安全碼結帳。 |
| `google_play_purchase_sheet.dart` | `lib/screens/premium/google_play_purchase_sheet.dart` | Google Play 內購彈窗 | 支援 Android 應用程式內購（IAP）結帳介面。 |
| `subscription_management_screen.dart` | `lib/screens/premium/subscription_management_screen.dart` | 會員訂閱管理 | 查詢當前訂閱狀態、到期日、自動續約開關與取消訂閱。 |

---

## 十二、 個人中心、生詞本與相簿資料夾 (Profile & Vocab Folders)

| 檔案名稱 | 檔案路徑 | 功能名稱 | 功能說明 |
| :--- | :--- | :--- | :--- |
| `profile_screen.dart` | `lib/screens/profile/profile_screen.dart` | 個人檔案主頁 | 顯示頭像、學習雷達圖、生詞庫用量與功能選單入口。 |
| `personal_info_screen.dart` | `lib/screens/profile/personal_info_screen.dart` | 個人資料編輯頁 | 修改暱稱、自訂頭像、日語目標檢定等級。 |
| `change_password_screen.dart` | `lib/screens/profile/change_password_screen.dart` | 修改密碼 | 驗證舊密碼並設定全新安全密碼。 |
| `system_settings_screen.dart` | `lib/screens/profile/system_settings_screen.dart` | 系統設定頁 | 假名標注開關、語音播放速度、字體大小與推播通知設定。 |
| `badge_library_screen.dart` | `lib/screens/profile/badge_library_screen.dart` | 成就徽章館 | 展示連續學習、單字蒐集等已解鎖與未解鎖徽章牆。 |
| `upgrade_test_screen.dart` | `lib/screens/profile/upgrade_test_screen.dart` | 等級升階升級考 | 達成學習進度後進行升級考核測驗以晉級更高等級。 |
| `photo_folder_v2_screen.dart` | `lib/screens/profile/photo_folder_v2_screen.dart` | 生詞與照片資料夾 | 自訂分類生詞庫，管理各照片情境下的單字集。 |
| `folder_detail_screen.dart` | `lib/screens/profile/folder_detail_screen.dart` | 資料夾詳細內容 | 瀏覽單一資料夾內的單字卡片、播放語音與移除單字。 |
| `folder_card.dart` | `lib/screens/profile/folder_card.dart` | 資料夾卡片元件 | 展示單一資料夾封面、名稱與單字數量的小卡。 |
| `single_vocab_detail_screen.dart` | `lib/screens/profile/single_vocab_detail_screen.dart` | 單字詳細辭典頁 | 單字發音、羅馬拼音、中文翻譯、詞性與豐富例句展示。 |

---

## 十三、 服務層與 API 通訊 (Services & Utilities)

| 檔案名稱 | 檔案路徑 | 功能名稱 | 功能說明 |
| :--- | :--- | :--- | :--- |
| `api_client.dart` | `lib/utils/api_client.dart` | HTTP 請求核心客戶端 | 封裝 GET/POST/PUT/DELETE 請求，自動附帶 Bearer Token 與錯誤攔截。 |
| `auth_service.dart` | `lib/services/auth_service.dart` | 身分驗證服務 | 處理登入、註冊、Token 刷新、登出及校園驗證碼發送。 |
| `user_service.dart` | `lib/services/user_service.dart` | 使用者資料服務 | 取得/更新個人資訊、每日任務打卡、生詞庫擴充與好友 API。 |
| `ai_service.dart` | `lib/services/ai_service.dart` | AI 情境辨識與對話 | 照片上傳分析、對話生成、自然度評估、造句批閱服務。 |
| `article_service.dart` | `lib/services/article_service.dart` | 文章閱讀服務 | 取得文章列表、單篇內容、TTS 語音生成與閱讀測驗交卷。 |
| `tutor_service.dart` | `lib/services/tutor_service.dart` | AI 家教服務 | 家教問題發送與解答獲取之通訊介面。 |
| `notification_service.dart` | `lib/services/notification_service.dart` | 本地與推播通知服務 | 每日複習提醒、讀書會進度通知與系統廣播。 |
| `feature_guard.dart` | `lib/utils/feature_guard.dart` | 功能權限守衛 | 檢查拍照剩餘次數、AI 對話次數與 VIP/校園特權攔截。 |
| `constants.dart` | `lib/utils/constants.dart` | 全域常數設定 | 定義後端 BaseURL、API 路由、主題配色與點數規定。 |
| `helpers.dart` | `lib/utils/helpers.dart` | 通用輔助工具函式 | 日期格式化、字串防呆處理與 Toast 訊息提示。 |
| `badge_utils.dart` | `lib/utils/badge_utils.dart` | 徽章成就工具 | 成就條件判定邏輯與徽章圖示映射。 |
| `face_privacy.dart` | `lib/utils/face_privacy.dart` | 人臉隱私模糊處理 | 拍照後若偵測到人臉可進行模糊遮蔽保護隱私。 |
| `route_observer.dart` | `lib/utils/route_observer.dart` | 路由跳轉監聽器 | 追蹤使用者頁面訪問動向與返回重新整理事件。 |
| `sub_page_template.dart` | `lib/utils/sub_page_template.dart` | 次級頁面通用骨架 | 統一 AppBar 風格、返回按鈕與外邊距樣式範本。 |

---

## 十四、 資料模型層 (Data Models)

| 檔案名稱 | 檔案路徑 | 功能名稱 | 功能說明 |
| :--- | :--- | :--- | :--- |
| `user.dart` | `lib/models/user.dart` | 使用者實體模型 | 使用者帳號、等級、點數、訂閱身份與每日任務屬性映射。 |
| `scenario.dart` | `lib/models/scenario.dart` | 情境模型 | 照片辨識之場景、情境標題、難度與延伸對話結構。 |
| `vocabulary.dart` | `lib/models/vocabulary.dart` | 單字生詞模型 | 單字、假名、漢字、詞性、中文解釋、例句與音訊 URL。 |
| `article_model.dart` | `lib/models/article_model.dart` | 閱讀文章模型 | 文章標題、難度等級、日文原文、中文翻譯與測驗題結構。 |
| `question.dart` | `lib/models/question.dart` | 測驗題目模型 | 測驗題目、多選項、正解與詳解文字映射。 |
| `badge_model.dart` | `lib/models/badge_model.dart` | 徽章成就模型 | 徽章編號、名稱、解鎖描述與達成條件。 |
| `leaderboard.dart` | `lib/models/leaderboard.dart` | 排行榜實體模型 | 讀書會成員排名、每週貢獻積分與名次資料模型。 |

---

## 十五、 共用 UI 元件與彈窗 (Widgets & Dialogs)

| 檔案名稱 | 檔案路徑 | 功能名稱 | 功能說明 |
| :--- | :--- | :--- | :--- |
| `bottom_nav_bar.dart` | `lib/widgets/common/bottom_nav_bar.dart` | 底部主導覽列 | 包含首頁、相機、閱讀、社群、個人中心之快捷圖示導覽列。 |
| `furigana_text.dart` | `lib/widgets/common/furigana_text.dart` | 日語振假名標音元件 | 將日文漢字上方自動顯示平假名標註之排版元件。 |
| `app_drawer.dart` | `lib/widgets/common/app_drawer.dart` | 側邊抽屜選單 | 系統功能捷徑、設定與登出按鈕側選單。 |
| `radar_chart.dart` | `lib/widgets/common/radar_chart.dart` | 五維學習雷達圖 | 視覺化呈現聽力、字彙、文法、讀解與口說之能力圖表。 |
| `premium_locked_overlay.dart` | `lib/widgets/common/premium_locked_overlay.dart` | VIP 鎖定遮罩 | 當免費次數用盡時提示升級會員或解鎖的彈性遮罩。 |
| `staged_progress_overlay.dart` | `lib/widgets/common/staged_progress_overlay.dart` | 分段載入指示器 | AI 處理中多步驟動態進度展示條。 |
| `status_chip.dart` | `lib/widgets/common/status_chip.dart` | 狀態標籤晶片 | 顯示等級 (N1~N5)、校園教育標籤或 VIP 狀態之小晶片。 |
| `user_avatar.dart` | `lib/widgets/common/user_avatar.dart` | 使用者頭像元件 | 支援預設頭像、自訂圖片與圓角邊框樣式之元件。 |
| `avatar_picker.dart` | `lib/widgets/common/avatar_picker.dart` | 頭像挑選彈窗 | 提供多種日系可愛頭像供使用者挑選更換。 |
| `join_classroom_dialog.dart` | `lib/widgets/dialogs/join_classroom_dialog.dart` | 加入班級輸入彈窗 | 輸入老師提供的 6 碼隨機碼，送出驗證並加入班級。 |
| `level_up_dialog.dart` | `lib/widgets/dialogs/level_up_dialog.dart` | 晉級慶祝彈窗 | 學生升級晉階（如 N4 升至 N3）時的恭賀動畫與獎勵展示。 |
| `vocab_bottom_sheet.dart` | `lib/widgets/dialogs/vocab_bottom_sheet.dart` | 生詞加入收藏彈窗 | 快速將單字加入指定生詞資料夾之底部彈出選單。 |
| `daily_goal_card.dart` | `lib/widgets/home/daily_goal_card.dart` | 每日目標進度卡 | 首頁顯示今日拍照、單字、對話目標達成率之卡片。 |
| `recent_scenes_list.dart` | `lib/widgets/home/recent_scenes_list.dart` | 近期學習情境輪播 | 首頁橫向滾動複習近期辨識場景卡片。 |
| `vocab_card.dart` | `lib/widgets/scenario/vocab_card.dart` | 生詞卡片元件 | 封裝單字發音按鈕、漢字振假名與收藏星號之卡片。 |
