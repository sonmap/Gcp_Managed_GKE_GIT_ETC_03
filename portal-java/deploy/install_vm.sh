#!/usr/bin/env bash
set -euo pipefail

: "${CLOUD_RUN_ADAPTER_URL:?Run with CLOUD_RUN_ADAPTER_URL=https://<cloud-run-service-url>}"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root, for example: sudo CLOUD_RUN_ADAPTER_URL=... bash $0"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORTAL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if command -v apt-get >/dev/null 2>&1; then
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y nginx openjdk-17-jdk maven curl
elif command -v dnf >/dev/null 2>&1; then
  dnf install -y nginx java-17-openjdk-devel maven curl
elif command -v yum >/dev/null 2>&1; then
  yum install -y nginx java-17-openjdk-devel maven curl
else
  echo "Unsupported package manager. Install nginx, JDK 17, Maven and curl manually."
  exit 1
fi

cd "${PORTAL_DIR}"
mvn -DskipTests clean package

install -d -m 0755 /opt/datalake-portal
install -m 0644 target/datalake-portal-0.0.1-SNAPSHOT.jar /opt/datalake-portal/datalake-portal.jar

cat >/etc/datalake-portal.env <<EOF
CLOUD_RUN_ADAPTER_URL=${CLOUD_RUN_ADAPTER_URL}
EOF
chmod 0600 /etc/datalake-portal.env

cat >/etc/systemd/system/datalake-portal.service <<'EOF'
[Unit]
Description=Data Lake Java Portal PoC
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
EnvironmentFile=/etc/datalake-portal.env
ExecStart=/usr/bin/java -jar /opt/datalake-portal/datalake-portal.jar
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

install -m 0644 "${SCRIPT_DIR}/nginx.conf" /etc/nginx/conf.d/datalake-portal.conf
rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

nginx -t
systemctl daemon-reload
systemctl enable --now datalake-portal
systemctl enable --now nginx
systemctl restart nginx

sleep 3

echo "=== Java portal service ==="
systemctl --no-pager --full status datalake-portal || true

echo "=== Local health check ==="
curl -fsS http://127.0.0.1/ >/dev/null && echo "Portal OK: http://192.168.142.101/"
