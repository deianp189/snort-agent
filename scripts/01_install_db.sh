#!/usr/bin/env bash
    set -euo pipefail
    source "$(dirname "$0")/00_common.sh"

    apt-get update -y
    apt-get install -y sqlite3

    if [[ ! -f "$DB_PATH" ]]; then
      echo "🗄️  Creando base de datos SQLite en $DB_PATH"
      cat > /tmp/rsnort_schema.sql <<'SQL'
    CREATE TABLE IF NOT EXISTS alerts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT,
        proto TEXT,
        dir TEXT,
        src_addr TEXT,
        src_port INTEGER,
        dst_addr TEXT,
        dst_port INTEGER,
        msg TEXT,
        sid INTEGER,
        gid INTEGER,
        priority INTEGER,
        agent_id TEXT
    );
    CREATE TABLE IF NOT EXISTS system_metrics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
        cpu_usage REAL,
        memory_usage REAL,
        temperature REAL,
        disk_usage REAL,
        agent_id TEXT
    );
SQL
      sqlite3 "$DB_PATH" < /tmp/rsnort_schema.sql
      rm /tmp/rsnort_schema.sql
    fi
