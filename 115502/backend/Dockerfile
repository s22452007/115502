# 日語學習後端 —— Flask 服務打包映像
FROM python:3.13-slim

# 不產生 .pyc、log 即時輸出（方便在容器裡看訊息）
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# 先只複製套件清單並安裝（Docker 快取：清單沒變就不會重裝，build 更快）
COPY requirements.docker.txt .
RUN pip install --no-cache-dir -r requirements.docker.txt

# 再複製後端所有程式碼
COPY . .

# 5050 = 主 API（給手機 App）、5001 = 後台管理
EXPOSE 5050 5001

# 預設啟動主 API；後台由 docker-compose 另開一個服務、用不同指令跑
CMD ["python", "app.py"]
