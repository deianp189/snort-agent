#!/usr/bin/env python3
import sqlite3, psutil, os

DB_PATH = "/var/lib/rsnort-agent/rsnort_agent.db"
AGENT_ID = open("/etc/rsnort-agent/agent.id").read().strip()

conn = sqlite3.connect(DB_PATH, isolation_level=None)
conn.execute("PRAGMA journal_mode=WAL")

cpu = psutil.cpu_percent(interval=1)
mem = psutil.virtual_memory().percent
disk = psutil.disk_usage("/").percent
temp = None
try:
    temps = psutil.sensors_temperatures()
    if temps:
        temp = list(temps.values())[0][0].current
except Exception:
    pass

conn.execute("""INSERT INTO system_metrics
                (cpu_usage, memory_usage, temperature, disk_usage, agent_id)
                VALUES (?,?,?,?,?)""", (cpu, mem, temp, disk, AGENT_ID))
conn.close()
