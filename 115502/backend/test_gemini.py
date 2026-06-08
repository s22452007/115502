import os
from dotenv import load_dotenv

load_dotenv('.env', override=True)
api_key = os.getenv("GEMINI_API_KEY")
print(f"使用的金鑰：{api_key[:20]}...")

# 試各個模型
from google import genai
client = genai.Client(api_key=api_key)

for model_name in ['gemini-2.5-flash', 'gemini-2.0-flash-lite', 'gemini-2.5-flash-lite']:
    try:
        response = client.models.generate_content(model=model_name, contents='請用日文說你好，一句話就好')
        print(f"✅ {model_name} 成功：{response.text[:80]}")
        break
    except Exception as e:
        print(f"❌ {model_name} 失敗：{str(e)[:100]}")
