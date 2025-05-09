#!/usr/bin/env python3
import pymysql, psutil, os, datetime

DB_CNF = "/etc/rsnort-agent/db.cnf"
AGENT_ID = open("/etc/rsnort-agent/agent.id").read().strip()

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

conn = pymysql.connect(read_default_file=DB_CNF, autocommit=True)
with conn.cursor() as cur:
    cur.execute("""
        INSERT INTO system_metrics (cpu_usage, memory_usage, temperature, disk_usage, agent_id)
        VALUES (%s, %s, %s, %s, %s)
    """, (cpu, mem, temp, disk, AGENT_ID))
conn.close()
