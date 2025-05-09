#!/usr/bin/env python3
import pymysql
import psutil
import os

DB_CNF = "/etc/rsnort-agent/db.cnf"
AGENT_ID_FILE = "/etc/rsnort-agent/agent.id"

# Leer agent_id
with open(AGENT_ID_FILE, "r") as f:
    AGENT_ID = f.read().strip()

# Leer métricas del sistema
cpu = psutil.cpu_percent(interval=1)
mem = psutil.virtual_memory().percent
disk = psutil.disk_usage("/").percent

# Función robusta para temperatura
def get_temperature():
    try:
        temps = psutil.sensors_temperatures()
        if not temps:
            raise RuntimeError("No hay sensores disponibles")

        # Preferencia por coretemp
        if "coretemp" in temps:
            coretemps = temps["coretemp"]
            values = [t.current for t in coretemps if t.current and t.current > 10]
            if values:
                return round(sum(values) / len(values), 1)  # media de núcleos

        # Si no hay coretemp, usar el primer sensor útil
        for sensor_list in temps.values():
            for sensor in sensor_list:
                if sensor.current and sensor.current > 10:
                    return round(sensor.current, 1)

    except Exception as e:
        print(f"[WARN] Temperatura real no disponible: {e}", flush=True)

    # Fallback simulado: estimar por uso de CPU
    return round(35 + (cpu / 12), 1)

# Obtener temperatura
temp = get_temperature()

# Insertar en la base de datos
try:
    conn = pymysql.connect(
        read_default_file=DB_CNF,
        read_default_group='client',
        autocommit=True
    )
    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO system_metrics (cpu_usage, memory_usage, temperature, disk_usage, agent_id)
            VALUES (%s, %s, %s, %s, %s)
        """, (cpu, mem, temp, disk, AGENT_ID))
    print(f"[INFO] Métricas insertadas: CPU={cpu}%, Mem={mem}%, Temp={temp}°C, Disk={disk}%", flush=True)
except Exception as e:
    print(f"[ERROR] Fallo al insertar métricas: {e}", flush=True)
finally:
    if 'conn' in locals():
        conn.close()
