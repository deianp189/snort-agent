#!/usr/bin/env python3
from fastapi import FastAPI, HTTPException, Body
import sqlite3, subprocess, os

DB_PATH = "/var/lib/rsnort-agent/rsnort_agent.db"
AGENT_ID = open("/etc/rsnort-agent/agent.id").read().strip()
CUSTOM_RULES = "/usr/local/snort/etc/snort/custom.rules"

app = FastAPI(title="R‑Snort Agent API", version="1.0.0")

def query(sql, params=()):
    with sqlite3.connect(DB_PATH) as conn:
        conn.row_factory = sqlite3.Row
        cur = conn.execute(sql, params)
        return [dict(r) for r in cur.fetchall()]

@app.get("/status")
def status():
    snort_ok = subprocess.call(["systemctl", "is-active", "--quiet", "snort"]) == 0
    db_size = os.path.getsize(DB_PATH) if os.path.exists(DB_PATH) else 0
    return {"agent_id": AGENT_ID, "snort_running": snort_ok, "db_size": db_size}

@app.get("/alerts")
def get_alerts(limit: int = 100):
    return query("SELECT * FROM alerts ORDER BY id DESC LIMIT ?", (limit,))

@app.get("/metrics")
def get_metrics(limit: int = 1000):
    return query("SELECT * FROM system_metrics ORDER BY id DESC LIMIT ?", (limit,))

@app.get("/rules")
def get_rules():
    if not os.path.exists(CUSTOM_RULES):
        return {"rules": ""}
    return {"rules": open(CUSTOM_RULES).read()}

@app.put("/rules")
def put_rules(rules: str = Body(..., media_type="text/plain")):
    with open(CUSTOM_RULES, "w") as fh:
        fh.write(rules)
    subprocess.call(["systemctl", "restart", "snort"])
    return {"status": "restarted"}

@app.post("/restart")
def restart():
    subprocess.call(["systemctl", "restart", "snort"])
    return {"status": "snort_restarted"}
