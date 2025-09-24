#!/bin/bash

# Generate secure credentials for ClickStack components
# This script creates a .env file with secure passwords and credentials

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_DIR/.env"

echo "🔐 Generating ClickStack credentials..."

# Generate random passwords
CLICKHOUSE_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
PROMETHEUS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

# Create .env file
cat > "$ENV_FILE" << EOF
# ClickStack Environment Variables
# Generated on $(date)

# ClickHouse Configuration
CLICKHOUSE_USER=clickstack_user
CLICKHOUSE_PASSWORD=$CLICKHOUSE_PASSWORD
CLICKHOUSE_DB=otel

# Prometheus Configuration
PROMETHEUS_USER=prometheus
PROMETHEUS_PASSWORD=$PROMETHEUS_PASSWORD

# Grafana Configuration
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=$GRAFANA_ADMIN_PASSWORD

# MongoDB Configuration (for HyperDX)
MONGODB_USER=hyperdx
MONGODB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
MONGODB_DB=hyperdx

# Network Configuration
CLICKHOUSE_HTTP_PORT=8123
CLICKHOUSE_NATIVE_PORT=9000
CLICKHOUSE_PROMETHEUS_PORT=9090
PROMETHEUS_PORT=9090
GRAFANA_PORT=3000
HYPERDX_PORT=8080
ALERTMANAGER_PORT=9093
NODE_EXPORTER_PORT=9100
EOF

echo "✅ Credentials generated and saved to $ENV_FILE"
echo "🔒 ClickHouse User: clickstack_user"
echo "🔒 ClickHouse Password: $CLICKHOUSE_PASSWORD"
echo "🔒 Grafana Admin: admin"
echo "🔒 Grafana Password: $GRAFANA_ADMIN_PASSWORD"
echo ""
echo "⚠️  Please keep these credentials secure!"
echo "📝 You can now run: docker-compose up -d"