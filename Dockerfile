FROM python:3.11-slim
WORKDIR /app
RUN pip install flask requests
COPY . .
EXPOSE 5005
CMD ["python", "app.py"]
