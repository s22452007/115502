import google.generativeai as genai

# ⚠️ 注意看！你的新鑰匙必須是「AIzaSy」這六個字母開頭的喔！
TEST_KEY = "AIzaSyBu1YTfS7F0iToc4dAU8uK6pGORw7t59a4"

print(f"準備使用金鑰：{TEST_KEY[:10]}... (只顯示前10碼)")

try:
    genai.configure(api_key=TEST_KEY)
    model = genai.GenerativeModel('gemini-1.5-flash')
    print("正在呼叫 Gemini，請稍候...")
    
    response = model.generate_content("請用日文對我說一句：你好，世界！")
    print("✅ 測試成功！Gemini 的回答是：", response.text)
    
except Exception as e:
    print("❌ 測試失敗！錯誤訊息：", e)