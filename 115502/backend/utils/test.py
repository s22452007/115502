import os
import google.generativeai as genai
from dotenv import load_dotenv

# 抓取你剛剛已經設定好的完美 .env 金鑰
load_dotenv(override=True)
my_secret_key = os.getenv("GEMINI_API_KEY") 

print(f"🔑 正在使用金鑰：{my_secret_key[:10]}... 向 Google 索取菜單")
genai.configure(api_key=my_secret_key)

try:
    print("📜 這是您目前可以使用的 AI 模型清單：")
    print("-" * 30)
    for m in genai.list_models():
        if 'generateContent' in m.supported_generation_methods:
            # 只印出能用來聊天的模型
            print(f"👉 菜名： {m.name.replace('models/', '')}")
    print("-" * 30)
    print("✅ 請從上面挑選一個『菜名』，填進 app.py 裡面！")
except Exception as e:
    print(f"❌ 查詢失敗: {e}")