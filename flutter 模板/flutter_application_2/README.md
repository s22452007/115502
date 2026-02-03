# 🐱🐶 AI 圖片辨識系統

這是一個使用 Flutter 開發的多功能圖片辨識應用程式，整合了**手寫數字辨識 (0-9)** 和**貓狗圖片辨識**兩大功能。

## ✨ 功能特色

### 🔐 登錄系統
- 📝 **帳號密碼登錄**：簡易登錄機制（輸入任意帳號密碼即可）
- 🎯 **功能選擇**：登錄後選擇要使用的辨識功能
- 🎨 **漸層介面設計**：現代化的 Material Design 3 風格

### 🔢 手寫數字辨識 (MNIST)
- ✍️ 辨識手寫數字 0-9
- 📸 支援拍照或相簿選擇
- 🎯 使用 Logistic Regression 模型
- 📏 28×28 灰階圖片處理

### 🐱🐶 貓狗圖片辨識
- 🐾 辨識照片中是貓還是狗
- 📸 支援拍照或相簿選擇
- 🤖 智能分類顯示結果
- 📊 顯示預測信心度百分比
- 🎨 64×64 RGB 彩色圖片處理

### 🌐 跨平台支援
- ✅ Android、iOS、Web、Windows、macOS、Linux

## 🏗️ 專案架構

```
lib/
├── main.dart                          # 應用程式入口（載入兩個模型）
├── model/
│   ├── logistic_regression_mnist.dart # MNIST 數字辨識模型
│   └── cat_dog_classifier.dart        # 貓狗分類模型
└── pages/
    ├── login_page.dart                # 登錄頁面 ⭐ 新增
    ├── camera_digit_page.dart         # 數字辨識頁面
    └── cat_dog_page.dart              # 貓狗辨識頁面

assets/model/
├── mnist_logreg.json                  # MNIST 模型權重
└── cat_dog_model.json                 # 貓狗模型權重
```

## 🚀 使用方式

### 1️⃣ 啟動應用並登錄
- 開啟應用程式
- 輸入任意帳號和密碼（例如：admin / 123456）
- 選擇要使用的功能：
  - **手寫數字辨識 (0-9)**
  - **貓狗圖片辨識 🐱🐶**

### 2️⃣ 選擇圖片
- 點擊「拍照」按鈕開啟相機拍攝
- 或點擊「相簿」按鈕從相簿選擇照片

### 3️⃣ 開始辨識
- 選擇圖片後，點擊「開始辨識」按鈕
- 等待處理完成

### 4️⃣ 查看結果
- **數字辨識**：顯示預測的數字 (0-9)
- **貓狗辨識**：顯示「這是貓」或「這是狗」附帶信心度

## 🔧 技術細節

### 登錄頁面設計
- **驗證機制**：簡易驗證（只需輸入非空帳號密碼）
- **導航系統**：使用 Navigator 進行頁面跳轉
- **UI 設計**：
  - 漸層背景（深紫色 → 靛藍色）
  - 圓形 Logo 設計
  - 卡片式表單佈局
  - 響應式輸入框（密碼顯示/隱藏切換）

### 雙模型架構
- **並行載入**：使用 `Future.wait()` 同時載入兩個模型，提升啟動速度
- **模型傳遞**：透過建構子將模型實例傳遞到各頁面
- **記憶體優化**：模型只載入一次，多頁面共享

### 數字辨識處理流程
1. 圖片讀取
2. 灰階轉換
3. 縮放至 200px 寬度
4. 前景檢測（閾值 180）
5. 裁切並調整為 28×28
6. 標準化到 [0, 1]
7. 模型預測

### 貓狗辨識處理流程
1. 圖片讀取
2. 調整大小為 64×64
3. RGB 特徵提取（12,288 維）
4. 標準化到 [0, 1]
5. 模型預測
6. Softmax 機率計算

## 📝 重要提示

⚠️ **目前使用的是示範模型**

專案中的 `cat_dog_model.json` 僅為示範用途，**不具備實際辨識能力**。

### 如何使用真實模型

1. **訓練模型**：使用 Python + TensorFlow/PyTorch 訓練貓狗分類模型
2. **匯出權重**：將模型權重匯出為 JSON 格式
3. **替換檔案**：將 `assets/model/cat_dog_model.json` 替換為您的模型
4. **調整參數**：根據需要調整 `cat_dog_page.dart` 中的圖片處理參數

#### Python 模型訓練範例

```python
# 使用 scikit-learn 訓練簡單的 Logistic Regression
from sklearn.linear_model import LogisticRegression
import json

# 訓練模型 (假設您已有訓練資料)
model = LogisticRegression()
model.fit(X_train, y_train)

# 匯出權重
weights = {
    "W": model.coef_.tolist(),
    "b": model.intercept_.tolist()
}

with open('cat_dog_model.json', 'w') as f:
    json.dump(weights, f)
```

## 🛠️ 開發指南

### 執行專案

```bash
# 取得依賴套件
flutter pub get

# 執行應用程式
flutter run

# 指定平台執行
flutter run -d chrome    # Web
flutter run -d windows   # Windows
```

### 建置發布版本

```bash
# Android APK
flutter build apk --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

## 🎨 自訂修改

### 修改辨識類別

如果想改為其他類別（例如：貓vs老虎），請修改：

1. **模型類別名稱**：[cat_dog_classifier.dart](lib/model/cat_dog_classifier.dart#L10)
   ```dart
   final List<String> _classNames = ['貓', '老虎'];
   ```

2. **頁面標題**：[cat_dog_page.dart](lib/pages/cat_dog_page.dart#L173)
   ```dart
   title: const Text('🐱 貓虎圖片識別 🐯'),
   ```

### 調整圖片尺寸

修改 [cat_dog_page.dart](lib/pages/cat_dog_page.dart#L80) 中的 `targetSize`：

```dart
const targetSize = 128;  // 從 64 改為 128
```

## 📱 截圖預覽

應用程式包含：
- ✅ 清爽的 Material Design 介面
- ✅ 即時處理進度指示
- ✅ 漸層色彩顯示結果
- ✅ 響應式佈局設計

## 📄 授權

此專案為教學示範用途。
