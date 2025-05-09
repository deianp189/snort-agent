#!/usr/bin/env python3
from fastapi import FastAPI, HTTPException, Body
import pymysql, subprocess, os

# Cambios aquí: configuración del archivo y ID del agente
DB_CNF = "/etc/rsnort-agent/db.cnf"
AGENT_ID = open("/etc/rsnort-agent/agent.id").read().strip()
CUSTOM_RULES = "/usr/local/snort/etc/snort/custom.rules"

app = FastAPI(title="R‑Snort Agent API", version="1.1.0")

# Nueva función query utilizando pymysql y archivo de configuración
def query(sql, params=()):
    conn = pymysql.connect(read_default_file=DB_CNF, cursorclass=pymysql.cursors.DictCursor)
    with conn:
        with conn.cursor() as cur:
            cur.execute(sql, params)
            return cur.fetchall()

@app.get("/status")
def status():
    snort_ok = subprocess.call(["systemctl", "is-active", "--quiet", "snort"]) == 0
    return {"agent_id": AGENT_ID, "snort_running": snort_ok}

@app.get("/alerts")
def get_alerts(limit: int = 100):
    return query("SELECT * FROM alerts ORDER BY id DESC LIMIT %s", (limit,))

@app.get("/metrics")
def get_metrics(limit: int = 1000):
    return query("SELECT * FROM system_metrics ORDER BY id DESC LIMIT %s", (limit,))

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
