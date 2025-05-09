#!/usr/bin/env python3
import pymysql, json, os, time

DB_CNF = "/etc/rsnort-agent/db.cnf"
AGENT_ID_FILE = "/etc/rsnort-agent/agent.id"
ALERT_LOG = "/opt/snort/logs/live/alert_json.txt"

# Leer el ID del agente una sola vez
with open(AGENT_ID_FILE) as f:
    AGENT_ID = f.read().strip()

def insert_alert(rec):
    fields = (
        "timestamp", "proto", "dir", "src_addr", "src_port",
        "dst_addr", "dst_port", "msg", "sid", "gid",
        "priority", "country_code", "latitude", "longitude"
    )
    vals = [rec.get(k) for k in fields]
    
    try:
        conn = pymysql.connect(read_default_file=DB_CNF, autocommit=True)
        with conn.cursor() as cur:
            cur.execute(f"""
                INSERT INTO alerts ({','.join(fields)}, agent_id)
                VALUES ({','.join(['%s'] * len(fields))}, %s)
            """, vals + [AGENT_ID])
    except Exception as e:
        print(f"[ERROR] Fallo al insertar alerta: {e}")

def follow(path):
    with open(path, "r") as fh:
        fh.seek(0, os.SEEK_END)
        while True:
            line = fh.readline()
            if not line:
                time.sleep(0.2)
                continue
            try:
                data = json.loads(line)
                insert_alert(data)
            except json.JSONDecodeError:
                continue  # descartar líneas corruptas

while True:
    try:
        follow(ALERT_LOG)
    except FileNotFoundError:
        time.sleep(1)
