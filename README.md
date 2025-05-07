# Snort Agent

&#x20;

## 🔎 Descripción

**Snort Agent** transforma una instalación estándar de **Snort 3** en un **agente gestionado remotamente**. Incluye:

* Ingesta automática de alertas JSON desde `alert_json.txt` a una base **SQLite** local.
* Recopilación periódica de métricas del sistema (CPU, RAM, temperatura, disco).
* API REST (FastAPI) para consultar alertas, métricas, estado y gestionar reglas/reinicio de Snort.
* Integración con **Grafana** para visualización en tiempo real, con acceso anónimo y embedding.
* Rotación y backup de logs configurado por **logrotate** y **cron**.
* Instalación automatizada mediante `install.sh` y scripts modulares.

## 🚀 Características principales

* **Despliegue one‑click** en Ubuntu Server o Raspberry Pi.
* **Idempotencia**: ejecutar instalación varias veces sin romper la configuración.
* **Script modular** para instalar BBDD, Snort, Grafana y servicios Python.
* **API RESTful** documentada con Swagger en `/docs`.
* **Monitorización**: métricas cada 30 s, alertas en tiempo real.
* **Backup** diario de logs rotados y retención configurable.

## 📋 Requisitos

* **SO**: Ubuntu 20.04+ o Debian 10+
* **Privilegios**: permisos `root` para instalación.
* **Dependencias**: Bash, Python 3.8+, SQLite, Grafana, Snort 3

## 🛠️ Instalación

1. Clona el repositorio:

   ```bash
   git clone https://github.com/deianp189/snort-agent.git
   cd snort-agent
   ```

2. Ejecuta el instalador:

   ```bash
   sudo ./install.sh
   ```

3. Verifica servicios:

   ```bash
   systemctl status snort rsnort-api rsnort-ingest rsnort-metrics.timer grafana-server
   ```

4. Accede a las interfaces:

   * **API REST** (Swagger): `http://<IP>:8080/docs`
   * **Grafana** (anónimo): `http://<IP>:3000`

## ⚙️ Configuración

### Snort (`snort.lua`)

* Ruta: `/usr/local/snort/etc/snort/snort.lua`
* Asegúrate del bloque:

  ```lua
  alert_json = {
    file = true,
    limit = 50,
    fields = [[timestamp proto dir src_addr src_port dst_addr dst_port msg sid gid priority]]
  }
  ```

### API

* **Endpoints**:

  * `GET /status` — Estado del agente
  * `GET /alerts?limit=N` — Últimas N alertas
  * `GET /metrics?limit=N` — Últimas métricas
  * `GET /rules` — Reglas actuales
  * `PUT /rules` — Actualiza reglas (texto plano)
  * `POST /restart` — Reinicia Snort

### Grafana (`grafana.ini`)

* Secciones críticas:

  ```ini
  [security]
  allow_embedding = true

  [auth.anonymous]
  enabled = true

  [auth.jwt]
  enabled = false
  ```

### Rotación de logs

* Configuración en `/etc/logrotate.d/snort-alert-json`
* Backups en `/etc/cron.d/rsnort_backup` a las 01:00

## 📈 Uso

```bash
# Ver últimas alertas
curl http://localhost:8080/alerts?limit=5

# Ver estado
curl http://localhost:8080/status

# Ver métricas
curl http://localhost:8080/metrics?limit=10

# Cambiar reglas
curl -X PUT http://localhost:8080/rules \
     -H "Content-Type: text/plain" \
     --data-binary @mi_reglas.rules

# Reiniciar Snort
curl -X POST http://localhost:8080/restart
```

## ⚖️ Licencia

Este proyecto está bajo la licencia **MIT**. Consulta [LICENSE](LICENSE) para más detalles.
