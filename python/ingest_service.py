#!/usr/bin/env python3
import pymysql, json, os, time, datetime

DB_CNF = "/etc/rsnort-agent/db.cnf"
AGENT_ID_FILE = "/etc/rsnort-agent/agent.id"
ALERT_LOG = "/opt/snort/logs/live/alert_json.txt"

def normalize_ts(raw: str) -> str:
    try:
        t = datetime.datetime.strptime(raw, "%m/%d-%H:%M:%S.%f")
        t = t.replace(year=datetime.datetime.now().year)
        return t.strftime("%Y-%m-%d %H:%M:%S")
    except ValueError:
        pass

    try:
        t = datetime.datetime.fromisoformat(raw)
        return t.strftime("%Y-%m-%d %H:%M:%S")
    except ValueError:
        pass

    print(f"[WARN] Timestamp no reconocible: {raw}. Insertando tal cual.", flush=True)
    return raw

with open(AGENT_ID_FILE) as f:
    AGENT_ID = f.read().strip()

def insert_alert(rec):
    ts_original = rec.get("timestamp", "")
    ts_normalizado = normalize_ts(ts_original)
    if ts_normalizado == ts_original:
        print(f"[WARN] Timestamp no normalizado: {ts_original}", flush=True)
    rec["timestamp"] = ts_normalizado

    if rec["timestamp"] is None:
        print(f"[WARN] Alerta descartada por timestamp inválido: {rec}", flush=True)
        return

    fields = (
        "timestamp", "proto", "dir", "src_addr", "src_port",
        "dst_addr", "dst_port", "msg", "sid", "gid",
        "priority", "country_code", "latitude", "longitude"
    )
    vals = [rec.get(k) for k in fields]

    try:
        conn = pymysql.connect(
            read_default_file=DB_CNF,
            read_default_group='client',
            autocommit=True
        )
        with conn.cursor() as cur:
            cur.execute(f"""
                INSERT INTO alerts ({','.join(fields)}, agent_id)
                VALUES ({','.join(['%s'] * len(fields))}, %s)
            """, vals + [AGENT_ID])
            print(f"[INFO] Insertando alerta con timestamp: {rec['timestamp']}", flush=True)
    except Exception as e:
        print(f"[ERROR] Fallo al insertar alerta: {e}", flush=True)

def follow(path):
    alertas_vistas = set()
    while True:
        try:
            with open(path, "r") as fh:
                for linea in fh:
                    linea = linea.strip()
                    if not linea:
                        continue
                    clave = (linea.rfind('"timestamp"'), linea[-32:])
                    if clave in alertas_vistas:
                        continue
                    alertas_vistas.add(clave)

                    try:
                        data = json.loads(linea)
                        insert_alert(data)
                    except json.JSONDecodeError as e:
                        print(f"[WARN] JSON inválido ({e}): {linea[:120]}", flush=True)
        except FileNotFoundError:
            pass

        if len(alertas_vistas) > 10000:
            alertas_vistas.clear()

        time.sleep(1)

while True:
    try:
        follow(ALERT_LOG)
    except FileNotFoundError:
        time.sleep(1)
