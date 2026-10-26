import hashlib, hmac, json, os, secrets, sqlite3, time
from datetime import date as D
from pathlib import Path
from urllib.parse import urlparse
from fastapi import Depends, FastAPI, File, Form, Header, HTTPException, UploadFile
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

BASE = Path(__file__).parent
UPLOADS = BASE / "uploads"; UPLOADS.mkdir(exist_ok=True)
SECRET = os.environ.get("SECRET_KEY", "dev-secret").encode()
PASSWORD = os.environ.get("CREATOR_PASSWORD", "change-me")
EXT = {".png", ".jpg", ".jpeg", ".webp", ".gif"}
LANGS, FIELDS = ("en", "de"), ("title", "desc", "usage")

db = sqlite3.connect(BASE / "ideas.db", check_same_thread=False)
db.execute("create table if not exists ideas (date text primary key, data text not null)")
app = FastAPI(title="30 Day 30 Apps")


def sign(exp: int) -> str:
    return f"{exp}.{hmac.new(SECRET, str(exp).encode(), hashlib.sha256).hexdigest()}"


def creator(authorization: str = Header("")):
    try:
        exp, sig = authorization.removeprefix("Bearer ").split(".")
        ok = hmac.compare_digest(sign(int(exp)), f"{exp}.{sig}") and int(exp) > time.time()
    except ValueError:
        ok = False
    if not ok:
        raise HTTPException(401, "Unauthorized")


def check(day: str):
    try:
        D.fromisoformat(day)
    except ValueError:
        raise HTTPException(422, "Date must be YYYY-MM-DD")


def get(day: str):
    r = db.execute("select data from ideas where date=?", (day,)).fetchone()
    return {"date": day, **json.loads(r[0])} if r else None


class Login(BaseModel):
    password: str


@app.post("/api/login")
def login(b: Login):
    if not hmac.compare_digest(b.password.encode(), PASSWORD.encode()):
        time.sleep(1)
        raise HTTPException(401, "Wrong password")
    return {"token": sign(int(time.time()) + 8 * 3600)}


@app.get("/api/ideas")
def list_ideas():
    rows = db.execute("select date, data from ideas order by date").fetchall()
    return [{"date": d, "title": json.loads(x)["title"]} for d, x in rows]


@app.get("/api/ideas/{day}")
def one(day: str):
    check(day)
    idea = get(day)
    if not idea:
        raise HTTPException(404, "No idea for this day")
    return idea


@app.put("/api/ideas/{day}", dependencies=[Depends(creator)])
async def save(day: str, data: str = Form(...), keep: str = Form("[]"),
               files: list[UploadFile] = File(default=[])):
    check(day)
    body, keep_list = json.loads(data), json.loads(keep)
    old = (get(day) or {}).get("snapshots", [])
    kept = [s for s in old if s in keep_list]
    for s in set(old) - set(kept):
        (UPLOADS / s).unlink(missing_ok=True)
    for f in files:
        ext = Path(f.filename or "").suffix.lower()
        raw = await f.read()
        if ext not in EXT or len(raw) > 5_000_000:
            raise HTTPException(422, "Snapshots must be png/jpg/webp/gif, max 5 MB")
        name = f"{day}-{secrets.token_hex(4)}{ext}"
        (UPLOADS / name).write_bytes(raw)
        kept.append(name)
    url = str(body.get("app_url", "")).strip()
    if url and urlparse(url).scheme not in ("http", "https"):
        raise HTTPException(422, "App URL must start with http(s)")
    idea = {k: {l: str(body.get(k, {}).get(l, ""))[:20000] for l in LANGS} for k in FIELDS}
    idea.update(app_url=url, snapshots=kept)
    db.execute("insert or replace into ideas values (?,?)", (day, json.dumps(idea)))
    db.commit()
    return get(day)


@app.delete("/api/ideas/{day}", dependencies=[Depends(creator)])
def remove(day: str):
    check(day)
    for s in (get(day) or {}).get("snapshots", []):
        (UPLOADS / s).unlink(missing_ok=True)
    db.execute("delete from ideas where date=?", (day,))
    db.commit()
    return {"ok": True}


app.mount("/uploads", StaticFiles(directory=UPLOADS))
app.mount("/", StaticFiles(directory=BASE.parent / "frontend" / "static", html=True))
