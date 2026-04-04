import google.generativeai as genai

# 這把已經確認是真鑰匙，我們繼續用它
TEST_KEY = "AIzaSyBu1YTfS7F0iToc4dAU8uK6pGORw7t59a4" 
genai.configure(api_key=TEST_KEY)

print("🕵️ 正在向 Google 索取你能使用的 AI 模型清單...")

try:
    # 叫 Google 交出所有支援對話的模型
    for m in genai.list_models():
        if 'generateContent' in m.supported_generation_methods:
            print("👉 發現可用模型：", m.name)
            
    print("\n✅ 查詢完畢！請把上面印出的【可用模型】名字貼給我！")
    
except Exception as e:
    print("❌ 查詢失敗！錯誤訊息：", e)