# 30 Days · 30 Apps

Public read-only idea gallery (calendar | live app / snapshots | idea + usage), one creator login, EN/DE.

## Run
```
cd frontend && npm install && npm run build      # TypeScript -> static/main.js
cd ../backend
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
CREATOR_PASSWORD='your-password' SECRET_KEY="$(openssl rand -hex 32)" python -m uvicorn main:app --host 0.0.0.0 --port 8000
```
Open http://localhost:8000. Click "Creator login", pick a date, "Add or edit this day".

## Host
Any VPS/PaaS (Render, Fly.io, Railway, Hetzner): install `backend/requirements.txt` in the deployment environment and run `python -m uvicorn main:app --host 0.0.0.0 --port 8000` from `backend/` behind HTTPS.
Keep `backend/ideas.db` and `backend/uploads/` on a persistent volume. Set `CREATOR_PASSWORD` and `SECRET_KEY` as env vars.
