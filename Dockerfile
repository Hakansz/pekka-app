FROM python:3.11-slim
WORKDIR /app
RUN pip install flask requests gunicorn flask-limiter
COPY . .
EXPOSE 5005
CMD ["gunicorn", "--workers=2", "--bind=0.0.0.0:5005", "app:app"]
