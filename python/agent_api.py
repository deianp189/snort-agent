#!/usr/bin/env python3
from fastapi import FastAPI, HTTPException, Body, Response
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from fastapi.responses import FileResponse
from typing import List, Optional
import pymysql, subprocess, os, tempfile, re
import io
import json
import csv

# Configuración
DB_CNF = "/etc/rsnort-agent/db.cnf"
AGENT_ID = open("/etc/rsnort-agent/agent.id").read().strip()
CUSTOM_RULES = "/usr/local/snort/etc/snort/custom.rules"
COMMUNITY_RULES = "/usr/local/snort/etc/snort/snort3-community-rules/snort3-community.rules"
SNORT_CONF = "/usr/local/snort/etc/snort/snort.lua"
ARCHIVE_DIR = "/var/log/snort/archived"
ALERT_JSON = "/opt/snort/logs/live/alert_json.txt"

# Servicios gestionables
MANAGED_SERVICES = {
    "snort": "snort",
    "ingest": "rsnort-ingest.service",
    "metrics": "rsnort-metrics.timer"
}

# App FastAPI
app = FastAPI(title="R-Snort Agent API", version="1.2.0")

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Función auxiliar SQL
def query(sql, params=()):
    conn = pymysql.connect(read_default_file=DB_CNF, cursorclass=pymysql.cursors.DictCursor)
    with conn:
        with conn.cursor() as cur:
            cur.execute(sql, params)
            return cur.fetchall()

# === ENDPOINTS ===

@app.get("/status")
def status():
    snort_ok = subprocess.call(["systemctl", "is-active", "--quiet", "snort"]) == 0
    return {"agent_id": AGENT_ID, "snort_running": snort_ok}

@app.get("/services/status")
def get_service_status():
    status_data = {}
    for name, service in MANAGED_SERVICES.items():
        result = subprocess.run(["systemctl", "is-active", service], capture_output=True)
        status_data[name] = result.stdout.decode().strip()
    return status_data

@app.post("/services/restart")
def restart_service(name: str = Body(..., embed=True)):
    if name not in MANAGED_SERVICES:
        raise HTTPException(status_code=400, detail=f"Servicio desconocido: {name}")
    subprocess.call(["systemctl", "restart", MANAGED_SERVICES[name]])
    return {"status": f"{name} reiniciado"}

@app.get("/alerts")
def get_alerts(limit: int = 100):
    return query("SELECT * FROM alerts ORDER BY id DESC LIMIT %s", (limit,))

@app.get("/metrics")
def get_metrics(limit: int = 1000):
    return query("SELECT * FROM system_metrics ORDER BY id DESC LIMIT %s", (limit,))

@app.get("/rules")
def get_rules():
    def parse_rules(file_path: str, source: str):
        if not os.path.exists(file_path):
            return []
        parsed = []
        current_rule = ""
        with open(file_path) as f:
            for line in f:
                stripped = line.strip()
                if not stripped or stripped.startswith("#"):
                    continue
                current_rule += " " + stripped
                if ")" in stripped:
                    sid = re.search(r"sid\s*:\s*(\d+)\s*;", current_rule)
                    msg = re.search(r'msg\s*:\s*"([^"]+)"\s*;', current_rule)
                    parsed.append({
                        "raw": current_rule.strip(),
                        "sid": int(sid.group(1)) if sid else None,
                        "msg": msg.group(1) if msg else None,
                        "source": source
                    })
                    current_rule = ""
        return parsed

    custom_rules = parse_rules(CUSTOM_RULES, "custom")
    community_rules = parse_rules(COMMUNITY_RULES, "community")
    return {"rules": custom_rules + community_rules}

class RuleItem(BaseModel):
    rule: str

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

@app.delete("/rules/{sid}")
def delete_rule(sid: int):
    if not os.path.exists(CUSTOM_RULES):
        raise HTTPException(status_code=404, detail="Archivo custom.rules no encontrado")

    with open(CUSTOM_RULES, "r") as f:
        lines = f.readlines()

    pattern = re.compile(rf"\bsid\s*:\s*{sid}\s*;")
    new_lines = []
    buffer = ""

    for line in lines:
        if line.strip() == "" or line.strip().startswith("#"):
            new_lines.append(line)
            continue
        buffer += line
        if ")" in line:
            if not pattern.search(buffer):
                new_lines.append(buffer)
            buffer = ""

    with open(CUSTOM_RULES, "w") as f:
        f.writelines(new_lines)

    subprocess.call(["systemctl", "restart", "snort"])
    return {"status": f"Regla con SID {sid} eliminada y Snort reiniciado"}

@app.get("/archived-files", response_model=List[str])
def list_archived_files():
    if not os.path.exists(ARCHIVE_DIR):
        raise HTTPException(status_code=404, detail="Directorio de archivos archivados no encontrado")
    files = sorted([
        f for f in os.listdir(ARCHIVE_DIR)
        if os.path.isfile(os.path.join(ARCHIVE_DIR, f))
    ])
    return files

@app.get("/archived-files/{filename}")
def download_archived_file(filename: str):
    if "/" in filename or ".." in filename:
        raise HTTPException(status_code=400, detail="Nombre de archivo no válido")
    file_path = os.path.join(ARCHIVE_DIR, filename)
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="Archivo no encontrado")
    return FileResponse(path=file_path, filename=filename, media_type="application/gzip")

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

@app.get("/alerts/last")
def get_last_alert():
    if not os.path.exists(ALERT_JSON):
        raise HTTPException(status_code=404, detail="Archivo de alertas no encontrado")
    try:
        with open(ALERT_JSON, "r") as f:
            lines = f.readlines()
        for line in reversed(lines):
            try:
                return json.loads(line.strip())
            except json.JSONDecodeError:
                continue
        raise HTTPException(status_code=404, detail="No se encontró alerta válida")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

