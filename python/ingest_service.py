#!/usr/bin/env python3
import sqlite3, json, os, time

AGENT_ID_FILE = "/etc/rsnort-agent/agent.id"
DB_PATH = "/var/lib/rsnort-agent/rsnort_agent.db"
ALERT_LOG = "/opt/snort/logs/live/alert_json.txt"

with open(AGENT_ID_FILE) as f:
    AGENT_ID = f.read().strip()

conn = sqlite3.connect(DB_PATH, isolation_level=None, check_same_thread=False)
conn.execute("PRAGMA journal_mode=WAL")

def insert_alert(rec):
    fields = ("timestamp","proto","dir","src_addr","src_port","dst_addr","dst_port",
              "msg","sid","gid","priority")
    vals = [rec.get(k) for k in fields]
    conn.execute(f"""INSERT INTO alerts ({','.join(fields)}, agent_id)
                    VALUES (?,?,?,?,?,?,?,?,?,?,?,?)""", vals + [AGENT_ID])

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
            except Exception:
                pass  # descartar líneas corruptas

while True:
    try:
        follow(ALERT_LOG)
    except FileNotFoundError:
        time.sleep(1)
