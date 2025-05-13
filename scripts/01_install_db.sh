#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00_common.sh"

apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y mariadb-server

systemctl enable --now mariadb

mysql --defaults-extra-file="$DB_CNF" -e "quit" 2>/dev/null || {
  mysql -uroot <<SQL
CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL
}

# Esquema
mysql --defaults-extra-file="$DB_CNF" <<'SQL'
CREATE TABLE IF NOT EXISTS alerts (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  timestamp VARCHAR(255),
  proto VARCHAR(50),
  dir VARCHAR(10),
  src_addr VARCHAR(45),
  src_port INT,
  dst_addr VARCHAR(45),
  dst_port INT,
  msg VARCHAR(255),
  sid INT,
  gid INT,
  priority INT,
  country_code CHAR(2),
  latitude FLOAT,
  longitude FLOAT,
  agent_id VARCHAR(64)
);

CREATE TABLE IF NOT EXISTS system_metrics (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
  cpu_usage FLOAT,
  memory_usage FLOAT,
  temperature FLOAT,
  disk_usage FLOAT,
  agent_id VARCHAR(64)
);
SQL
echo "🗄️  MariaDB listo (DB $DB_NAME, usuario $DB_USER)"
