#!/bin/bash
echo "=== Pekka-App Säkerhetsfix ==="

# 1. Ny PIN
read -s -p "Välj ny PIN (4-8 siffror): " PIN
echo ""
sed -i "s/PEKKA_PIN=.*/PEKKA_PIN=$PIN/" docker-compose.yml
echo "✅ PIN satt"

# 2. Gunicorn i Dockerfile
cat > Dockerfile << 'DOCKER'
FROM python:3.11-slim
WORKDIR /app
RUN pip install flask requests gunicorn flask-limiter
COPY . .
EXPOSE 5005
CMD ["gunicorn", "--workers=2", "--bind=0.0.0.0:5005", "app:app"]
DOCKER
echo "✅ Gunicorn klar"

# 3. Rate limiting i app.py
sed -i 's/from flask import Flask/from flask import Flask\nfrom flask_limiter import Limiter\nfrom flask_limiter.util import get_remote_address/' app.py
sed -i 's/app.secret_key/limiter = Limiter(get_remote_address, app=app, default_limits=[])\n\napp.secret_key/' app.py
sed -i 's/@app.route("\/login"/@limiter.limit("10 per minute")\n@app.route("\/login"/' app.py
echo "✅ Rate limiting klar"

# 4. Bygg och starta
docker compose up --build -d
echo "✅ Container omstartad"

# 5. Tailscale Funnel permanent
tailscale funnel --bg 5008
echo "✅ Tailscale Funnel aktiv i bakgrunden"

# 6. Commit
git add .
git commit -m "security: gunicorn, rate limit, ny PIN"
git push
echo ""
echo "=== KLART ==="
echo "URL: https://ronny.taild6fe8c.ts.net/"
