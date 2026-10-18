import hmac
import json
import os
import smtplib
import time
from email.message import EmailMessage

import psycopg
import redis
from flask import Flask, abort, jsonify, render_template, request
from prometheus_client import CONTENT_TYPE_LATEST, Counter, generate_latest
from psycopg.rows import dict_row


def secret(name, default=None):
    path = os.environ.get(name + "_FILE")
    if path:
        with open(path) as f:
            return f.read().strip()
    return os.environ.get(name, default)


DB = f"host=db dbname=app user=app password={secret('DB_PASSWORD', 'app')}"
FEED_TOKEN = secret("FEED_TOKEN", "dev-token")
MAIL_FROM = os.environ.get("MAIL_FROM", "app@localhost")
REPORT_TO = os.environ.get("REPORT_TO", "admin@localhost")
CACHE_TTL = 30

SCHEMA = """
CREATE TABLE IF NOT EXISTS ratings (
    id          serial PRIMARY KEY,
    url         text NOT NULL,
    title       text,
    value       real NOT NULL,
    best        real,
    reviews     integer,
    captured_at timestamptz NOT NULL DEFAULT now()
)"""

SUMMARY = """
SELECT DISTINCT ON (url) url, title, value, best, reviews,
       to_char(captured_at, 'YYYY-MM-DD HH24:MI') AS captured_at
FROM ratings
ORDER BY url, captured_at DESC"""

CACHE = Counter("app_cache_requests_total", "Summary lookups in Redis", ["result"])
RATINGS = Counter("app_ratings_total", "Ratings received from the feeder")

app = Flask(__name__)
cache = redis.Redis(host="redis", socket_timeout=1)


def connect():
    return psycopg.connect(DB, row_factory=dict_row)


# Wait for the db while it starts
for attempt in range(30):
    try:
        with connect() as conn:
            conn.execute(SCHEMA)
        break
    except psycopg.Error:
        time.sleep(2)
else:
    raise SystemExit("core: database not reachable")


# Cache-aside: Redis first, then the db. If Redis is down, the db still works.
def summary():
    try:
        cached = cache.get("summary")
        if cached:
            CACHE.labels("hit").inc()
            return json.loads(cached)
        CACHE.labels("miss").inc()
    except redis.RedisError:
        CACHE.labels("error").inc()
    with connect() as conn:
        rows = conn.execute(SUMMARY).fetchall()
    try:
        cache.setex("summary", CACHE_TTL, json.dumps(rows))
    except redis.RedisError:
        pass
    return rows


def check_token():
    if not hmac.compare_digest(request.headers.get("X-Feed-Token", ""), FEED_TOKEN):
        abort(401)


@app.get("/")
def index():
    return render_template("index.html", pages=summary())


@app.get("/api/pages")
def pages():
    return jsonify(summary())


@app.post("/api/ratings")
def add_rating():
    check_token()
    r = request.get_json(silent=True) or {}
    if "url" not in r or "value" not in r:
        abort(400)
    with connect() as conn:
        conn.execute(
            "INSERT INTO ratings (url, title, value, best, reviews) VALUES (%s, %s, %s, %s, %s)",
            (r["url"], r.get("title"), r["value"], r.get("best"), r.get("reviews")))
    RATINGS.inc()
    return {"status": "ok"}, 201


@app.post("/api/report")
def report():
    check_token()
    rows = summary()
    msg = EmailMessage()
    msg["Subject"] = f"Ratings report: {len(rows)} pages"
    msg["From"] = MAIL_FROM
    msg["To"] = REPORT_TO
    msg.set_content("\n".join(f"{p['title'] or p['url']}: {p['value']}/{p['best'] or '?'}"
                              for p in rows) or "No data yet.")
    with smtplib.SMTP("smtp", 2525, timeout=10) as s:
        s.send_message(msg)
    return {"status": "sent", "to": REPORT_TO}


@app.get("/healthz")
def healthz():
    return "ok\n"


@app.get("/metrics")
def metrics():
    return generate_latest(), {"Content-Type": CONTENT_TYPE_LATEST}
