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
            print(f"[INFO] Insertada alerta con timestamp: {rec['timestamp']}", flush=True)
    except Exception as e:
        print(f"[ERROR] Fallo al insertar alerta: {e}", flush=True)

def follow_file(path):
    alertas_vistas = set()
    fh = None
    last_inode = None
    last_data_time = time.time()

    while True:
        try:
            stat_info = os.stat(path)
            inode_actual = stat_info.st_ino

            # Detectar primera apertura o rotación
            if fh is None or inode_actual != last_inode:
                if fh:
                    fh.close()
                fh = open(path, "r")

                if last_inode is None:
                    # Solo al inicio, no tras cada rotación
                    fh.seek(0, os.SEEK_END)

                last_inode = inode_actual
                print(f"[INFO] Reabierto archivo: {path}", flush=True)

            linea = fh.readline()
            if not linea:
                if time.time() - last_data_time > 10:
                    print("[INFO] Reintentando por inactividad...", flush=True)
                    fh.close()
                    fh = None
                time.sleep(0.5)
                continue

            linea = linea.strip()
            if not linea:
                continue

            clave = hash(linea)
            if clave in alertas_vistas:
                continue
            alertas_vistas.add(clave)

            try:
                data = json.loads(linea)
                insert_alert(data)
                last_data_time = time.time()
            except json.JSONDecodeError as e:
                print(f"[WARN] JSON inválido ({e}): {linea[:120]}", flush=True)

            if len(alertas_vistas) > 10000:
                alertas_vistas.clear()

        except FileNotFoundError:
            print(f"[WARN] Archivo no encontrado: {path}. Esperando...", flush=True)
            time.sleep(1)
        except Exception as e:
            print(f"[ERROR] Fallo inesperado en follow_file: {e}", flush=True)
            time.sleep(1)

follow_file(ALERT_LOG)
