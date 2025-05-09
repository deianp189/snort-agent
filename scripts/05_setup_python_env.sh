#!/usr/bin/env bash
set -euo pipefail
VENV=/opt/rsnort-agent/venv

apt-get install -y python3-venv python3-pip
python3 -m venv "$VENV"

"$VENV/bin/pip" install --upgrade pip
"$VENV/bin/pip" install fastapi 'uvicorn[standard]' psutil PyMySQL
