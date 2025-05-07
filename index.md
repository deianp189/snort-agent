# Snort Agent

> **R‑Snort Agent** convierte cualquier instancia de Snort 3 en un agente gestionado remotamente mediante API REST, con ingesta automática de alertas y métricas en SQLite, integración con Grafana y rotación de logs.

---

## 📂 Estructura del repositorio

```text
.
├── install.sh
├── python
│   ├── agent_api.py
│   ├── ingest_service.py
│   └── metrics_timer.py
├── README.md
└── scripts
    ├── 00_common.sh
    ├── 01_install_db.sh
    ├── 02_configure_snort.sh
    ├── 03_log_rotation.sh
    ├── 04_setup_grafana.sh
    ├── 05_setup_python_env.sh
    ├── 06_install_services.sh
    └── backup_logs.sh
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

3. **Verifica**:

   * API REST → `http://<IP_DEL_SERVIDOR>:8080/docs`
   * Grafana    → `http://<IP_DEL_SERVIDOR>:3000`

---

## ⚙️ Configuración

### Parámetros principales

* **Directorio logs**: `/opt/snort/logs/live`
* **Base de datos**: `/var/lib/rsnort-agent/rsnort_agent.db` (SQLite)
* **API**: puerto `8080`
* **Métricas**: cada 30 s en la tabla `system_metrics`
* **Grafana**: anónimo, embedding habilitado

### Personalización

* Edita `/usr/local/snort/etc/snort/snort.lua` para ajustar reglas o preprocesadores.
* Personaliza el crontab en `/etc/cron.d/rsnort_backup` para cambiar horarios de backup.

---

## 📖 Uso

### Consultar alertas (REST)

```bash
curl http://localhost:8080/alerts?limit=10
```

### Obtener métricas

```bash
curl http://localhost:8080/metrics?limit=20
```

### Reiniciar Snort

```bash
curl -X POST http://localhost:8080/restart
```

---

## 🐞 Resolución de problemas

* **No genera alertas**: asegúrate de que existe el bloque `alert_json` en `snort.lua` y que el servicio Snort está activo.
* **No arranca Grafana**: revisa `/etc/grafana/grafana.ini` y desactiva JWT:

  ```ini
  [auth.jwt]
  enabled = false
  ```
* **Permisos**: ejecuta:

  ```bash
  sudo chown -R root:root /opt/snort/logs/live
  sudo chown -R grafana:grafana /var/lib/grafana /var/log/grafana
  ```

---

## 🤝 Contribuir

1. Haz un **fork**
2. Crea una **rama** (`git checkout -b feature/nueva-característica`)
3. Realiza los **cambios** y haz **commit**
4. Empuja tu rama (`git push origin feature/nueva-característica`)
5. Abre un **Pull Request**

---

## 📝 Licencia

MIT © 2025 deianp189
