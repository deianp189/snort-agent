# R‑Snort Agent

Instalador y scripts para convertir una instancia R‑Snort en un agente manejable remotamente
mediante REST.

```bash
# Copia el archivo en el host y descomprímelo
tar -xzf rsnort-agent.tar.gz
cd rsnort-agent
sudo ./install.sh
```

Servicios instalados:

* **snort.service** (modificado) — IDS
* **rsnort-ingest.service** — ingesta de alertas en SQLite
* **rsnort-api.service** — API REST (puerto 8080)
* **rsnort-metrics.timer** — métricas de sistema cada 30 s
* **grafana-server.service** — Grafana sin auth (puerto 3000)

Los logs de alertas se rotan a 200 MB y se archivan diariamente en
`/var/log/snort/archived`.
