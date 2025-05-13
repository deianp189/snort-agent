# Snort Agent

> **R‑Snort Agent** convierte cualquier instancia de Snort 3 en un agente gestionado remotamente mediante API REST, con ingesta automática de alertas y métricas, integración con Grafana, y rotación de logs preconfigurada.

---

## 📂 Estructura del repositorio

```text
.
├── install.sh
├── dashboard_instance.json
├── python
│   ├── agent_api.py
│   ├── ingest_service.py
│   └── metrics_timer.py
├── scripts
│   ├── 00_common.sh
│   ├── 01_install_db.sh
│   ├── 02_configure_snort.sh
│   ├── 03_log_rotation.sh
│   ├── 04_setup_grafana.sh
│   ├── 05_setup_python_env.sh
│   ├── 06_install_services.sh
│   ├── 07_import_dashboard.sh
│   └── backup_logs.sh
├── docs
│   └── index.md
├── index.md
└── README.md
```

---

## 🚀 Instalación

1. **Clona el repositorio**:

   ```bash
   git clone https://github.com/deianp189/snort-agent.git
   cd snort-agent
   ```

2. **Ejecuta el instalador**:

   ```bash
   sudo ./install.sh
   ```

3. **Verifica servicios**:

   ```bash
   systemctl status snort rsnort-api rsnort-ingest rsnort-metrics.timer grafana-server
   ```

4. **Accede a las interfaces**:

   * API REST → `http://<IP_DEL_SERVIDOR>:8080/docs`
   * Grafana → `http://<IP_DEL_SERVIDOR>:3000` (sin login)

---

## ⚙️ Configuración

### Parámetros clave

* **Logs de Snort**: `/opt/snort/logs/live/alert_json.txt`
* **Base de datos**: `/var/lib/rsnort-agent/rsnort_agent.db` (SQLite)
* **API REST**: Puerto `8080` (FastAPI)
* **Métricas**: se almacenan cada 30 s
* **Grafana**: anónimo, con embedding habilitado
* **Dashboard JSON**: `dashboard_instance.json` (variable `${snort}` embebida)

### Rotación de logs

* Logrotate en `/etc/logrotate.d/snort-alert-json`
* Backup diario (cron) a las 01:00 → `/etc/cron.d/rsnort_backup`

---

## 📊 Visualización

El dashboard de Grafana se instala automáticamente en el script `07_import_dashboard.sh`.
Usa `${snort}` como variable de datasource, mapeada internamente a `Snort-MariaDB`, y contiene:

* Temperatura CPU
* Estadísticas por severidad
* Historial de alertas
* Uso de recursos

---

## 📖 Endpoints API REST

| Método | Ruta       | Descripción                  |
| ------ | ---------- | ---------------------------- |
| GET    | `/alerts`  | Últimas alertas              |
| GET    | `/metrics` | Métricas del sistema         |
| GET    | `/status`  | Estado del sistema           |
| GET    | `/rules`   | Reglas activas               |
| PUT    | `/rules`   | Subir nuevas reglas          |
| POST   | `/restart` | Reinicia el proceso de Snort |

---

## 🔎 Resolución de problemas

* **Grafana no carga el dashboard**: asegúrate de que no quedan referencias a `${DS_SNORT-MARIADB}` en el JSON.
* **No se generan alertas**: revisa `snort.lua` y asegúrete de que la sección `alert_json` está habilitada.
* **Permisos de logs**:

  ```bash
  sudo chown -R root:root /opt/snort/logs/live
  sudo chown -R grafana:grafana /var/lib/grafana /var/log/grafana
  ```

---

## 🤝 Contribución

1. Forkea este repositorio
2. Crea una rama (`git checkout -b mejora-x`)
3. Realiza los cambios y haz commit
4. Abre un Pull Request

---

## 📝 Licencia

MIT © 2025 Deian Orlando Petrovics
