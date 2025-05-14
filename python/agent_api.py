#!/usr/bin/env python3
from fastapi import FastAPI, HTTPException, Body, Response
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from fastapi.responses import FileResponse
from typing import List
import pymysql, subprocess, os, tempfile, re
import io
import json
import csv

# Constantes de configuración
DB_CNF = "/etc/rsnort-agent/db.cnf"
AGENT_ID = open("/etc/rsnort-agent/agent.id").read().strip()
CUSTOM_RULES = "/usr/local/snort/etc/snort/custom.rules"
SNORT_CONF = "/usr/local/snort/etc/snort/snort.lua"
ARCHIVE_DIR = "/var/log/snort/archived"
ALERT_JSON = "/opt/snort/logs/live/alert_json.txt"

# Instancia FastAPI
app = FastAPI(title="R-Snort Agent API", version="1.1.0")

# Habilita CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Función para hacer consultas SQL
def query(sql, params=()):
    conn = pymysql.connect(read_default_file=DB_CNF, cursorclass=pymysql.cursors.DictCursor)
    with conn:
        with conn.cursor() as cur:
            cur.execute(sql, params)
            return cur.fetchall()

# Estado del agente
@app.get("/status")
def status():
    snort_ok = subprocess.call(["systemctl", "is-active", "--quiet", "snort"]) == 0
    return {"agent_id": AGENT_ID, "snort_running": snort_ok}

# Alertas desde MariaDB
@app.get("/alerts")
def get_alerts(limit: int = 100):
    return query("SELECT * FROM alerts ORDER BY id DESC LIMIT %s", (limit,))

# Métricas del sistema
@app.get("/metrics")
def get_metrics(limit: int = 1000):
    return query("SELECT * FROM system_metrics ORDER BY id DESC LIMIT %s", (limit,))

# Obtener reglas parseadas desde el archivo custom.rules
@app.get("/rules")
def get_rules():
    if not os.path.exists(CUSTOM_RULES):
        return {"rules": []}

    rules = []
    with open(CUSTOM_RULES) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                sid = re.search(r"sid:(\d+);", line)
                msg = re.search(r'msg:"([^"]+)";', line)
                rules.append({
                    "raw": line,
                    "sid": int(sid.group(1)) if sid else None,
                    "msg": msg.group(1) if msg else None
                })
    return {"rules": rules}

# Modelo para validar reglas nuevas
class RuleItem(BaseModel):
    rule: str

# Añadir regla personalizada
@app.post("/rules")
def add_rule(item: RuleItem):
    rule = item.rule.strip()

    if not rule.startswith("alert") or "sid:" not in rule:
        raise HTTPException(status_code=400, detail="Regla no válida: debe comenzar con 'alert' y contener 'sid:'")

    with tempfile.NamedTemporaryFile("w", delete=False) as tmp:
        tmp.write(rule + "\n")
        tmp_path = tmp.name

    cmd = ["snort", "-T", "-c", SNORT_CONF, "-R", tmp_path]
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    os.unlink(tmp_path)

    output = result.stdout.decode(errors="replace").strip()
    if result.returncode != 0:
        lines = output.splitlines()
        relevant_error = "\n".join(lines[-15:]) if len(lines) > 15 else output
        raise HTTPException(status_code=400, detail=f"Error de validación de regla:\n{relevant_error}")

    with open(CUSTOM_RULES, "a") as f:
        f.write(rule + "\n")

    subprocess.call(["systemctl", "restart", "snort"])
    sid = re.search(r"sid:(\d+);", rule)
    msg = re.search(r'msg:"([^"]+)"', rule)
    return {
        "status": "regla añadida y Snort reiniciado",
        "sid": int(sid.group(1)) if sid else None,
        "msg": msg.group(1) if msg else None
    }

# Reinicio manual de Snort
@app.post("/restart")
def restart():
    subprocess.call(["systemctl", "restart", "snort"])
    return {"status": "snort_restarted"}

# Listar archivos rotados disponibles para descarga
@app.get("/archived-files", response_model=List[str])
def list_archived_files():
    if not os.path.exists(ARCHIVE_DIR):
        raise HTTPException(status_code=404, detail="Directorio de archivos archivados no encontrado")

    files = sorted([
        f for f in os.listdir(ARCHIVE_DIR)
        if os.path.isfile(os.path.join(ARCHIVE_DIR, f))
    ])
    return files

# Descargar archivo rotado por nombre
@app.get("/archived-files/{filename}")
def download_archived_file(filename: str):
    if "/" in filename or ".." in filename:
        raise HTTPException(status_code=400, detail="Nombre de archivo no válido")

    file_path = os.path.join(ARCHIVE_DIR, filename)
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="Archivo no encontrado")

    return FileResponse(path=file_path, filename=filename, media_type="application/gzip")

# Descargar alert_json.txt como CSV
@app.get("/download-alerts", summary="Descargar alertas activas como CSV", response_class=Response)
def download_alerts_csv():
    if not os.path.exists(ALERT_JSON):
        raise HTTPException(status_code=404, detail="No se encontró el archivo de alertas")

    csv_buffer = io.StringIO()
    writer = csv.DictWriter(csv_buffer, fieldnames=[
        "timestamp", "proto", "dir", "src_addr", "src_port",
        "dst_addr", "dst_port", "msg", "sid", "gid", "priority"
    ])
    writer.writeheader()
    with open(ALERT_JSON, "r") as f:
        for line in f:
            try:
                entry = json.loads(line.strip())
                writer.writerow(entry)
            except json.JSONDecodeError:
                continue

    return Response(
        content=csv_buffer.getvalue(),
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename=alerts_agent_{AGENT_ID}.csv"}
    )
