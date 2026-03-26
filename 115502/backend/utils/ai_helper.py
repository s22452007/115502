import os
import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
# 預期模型放在 backend/utils 下
MODEL_PATH = os.path.join(BASE_DIR, 'efficientnet_lite0.tflite')

def analyze_image_from_path(file_path):
    """
    使用 Google MediaPipe 的 Image Classifier 進行圖像分析。
    """
    try:
        # 確認模型存在
        if not os.path.exists(MODEL_PATH):
            return {"success": False, "error": f"找不到模型檔案: {MODEL_PATH}"}

        # 1. 建立 ImageClassifier 實例
        base_options = python.BaseOptions(model_asset_path=MODEL_PATH)
        # 設定回傳前 5 個最可能的標籤，過濾掉分數低於 0.1 的結果
        options = vision.ImageClassifierOptions(
            base_options=base_options,
            max_results=5,
            score_threshold=0.1
        )

        with vision.ImageClassifier.create_from_options(options) as classifier:
            # 2. 載入圖片 (透過 mediapipe 的 Image 物件)
            mp_image = mp.Image.create_from_file(file_path)
            
            # 3. 執行分類
            classification_result = classifier.classify(mp_image)
            
            # 4. 處理解析結果
            labels = []
            if classification_result.classifications:
                # classifications[0] 代碼第一張圖的結果
                for category in classification_result.classifications[0].categories:
                    # MediaPipe 回傳的標籤通常是英文，例："laptop", "coffee mug"
                    labels.append(category.category_name)
                    
            if not labels:
                labels = ["Unknown Object"]
                
            return {
                "success": True,
                "result": {
                    "labels": labels,
                    "text": "" # MediaPipe 基礎圖像分類不包含文字辨識，暫留空
                }
            }
            
    except Exception as e:
        print(f"MediaPipe 分析錯誤: {e}")
        return {
            "success": False,
            "error": str(e)
        }
