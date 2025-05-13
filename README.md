# Snort Agent

Sistema modular para convertir Snort 3 en un agente gestionado vía REST API con ingesta automática, métricas del sistema y visualización en Grafana.

---

## 🔎 Descripción

**Snort Agent** transforma una instalación estándar de **Snort 3** en un entorno completo de monitorización para PYMEs o redes domésticas:

* Ingesta automática de alertas desde `alert_json.txt`
* Base de datos SQLite con alertas y métricas
* API REST (FastAPI) con documentación Swagger
* Dashboards automáticos en Grafana (con acceso anónimo)
* Scripts modulares para instalación completa y sin intervención

---

## 🚀 Características principales

* Despliegue "one-click" compatible con Raspberry Pi y Ubuntu Server
* Dashboard de Grafana configurado automáticamente usando la variable `${snort}`
* API REST para consultar alertas, métricas, reglas y reiniciar Snort
* Servicio Python de ingesta en tiempo real y recolección de métricas del sistema
* Logrotate + cron configurado por defecto para rotación y backup

---

## 📋 Requisitos

* Ubuntu 20.04+ o Debian 10+
* Python 3.8+, Bash, SQLite, Grafana, Snort 3
* Acceso root durante la instalación

---

## 🛠️ Instalación

```bash
git clone https://github.com/deianp189/snort-agent.git
cd snort-agent
sudo ./install.sh
```

---

## 🔗 Accesos y verificación

```bash
systemctl status snort rsnort-api rsnort-ingest rsnort-metrics.timer grafana-server
```

* API REST: [http://localhost:8080/docs](http://localhost:8080/docs)
* Grafana: [http://localhost:3000](http://localhost:3000)

---

## ⚙️ Configuración

### Snort (`snort.lua`)

Ruta: `/usr/local/snort/etc/snort/snort.lua`

```lua
alert_json = {
  file = true,
  limit = 50,
  fields = [[timestamp proto dir src_addr src_port dst_addr dst_port msg sid gid priority]]
}
```

### API (FastAPI)

| Método | Ruta       | Descripción                     |
| ------ | ---------- | ------------------------------- |
| GET    | `/alerts`  | Últimas alertas                 |
| GET    | `/metrics` | Métricas del sistema            |
| GET    | `/status`  | Estado del sistema              |
| GET    | `/rules`   | Reglas activas                  |
| PUT    | `/rules`   | Subir nuevas reglas (plaintext) |
| POST   | `/restart` | Reinicia Snort                  |

### Grafana (`grafana.ini`)

```ini
[security]
allow_embedding = true

[auth.anonymous]
enabled = true

[auth.jwt]
enabled = false
```

### Rotación de logs

* Logrotate: `/etc/logrotate.d/snort-alert-json`
* Cron diario: `/etc/cron.d/rsnort_backup` (01:00)

---

## 📊 Uso básico

```bash
# Ver últimas alertas
curl http://localhost:8080/alerts?limit=5

# Ver estado
dcurl http://localhost:8080/status

# Ver métricas
curl http://localhost:8080/metrics?limit=10

# Cambiar reglas
curl -X PUT http://localhost:8080/rules \
     -H "Content-Type: text/plain" \
     --data-binary @mi_reglas.rules

# Reiniciar Snort
curl -X POST http://localhost:8080/restart
```

---

## ⚖️ Licencia

Este proyecto está bajo la licencia **MIT**. Consulta [LICENSE](https://choosealicense.com/licenses/mit/) para más detalles.
