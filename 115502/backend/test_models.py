import os
import google.generativeai as genai
from dotenv import load_dotenv

load_dotenv('c:/Users/Administrator/115502/115502/backend/.env')
# print out the key length to make sure it's loaded
key = os.environ.get('GEMINI_API_KEY')
print(f"Key loaded: {bool(key)} length: {len(key) if key else 0}")
genai.configure(api_key=key)

try:
    models = genai.list_models()
    for m in models:
        if "generateContent" in m.supported_generation_methods:
            print(m.name)
except Exception as e:
    print(f"Error: {e}")
