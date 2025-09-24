#!/bin/bash
# Create all configuration directories and files
mkdir -p clickhouse prometheus alertmanager grafana/datasources grafana/dashboards

# ===========================================
# ClickHouse Configuration
# ===========================================

# clickhouse/prometheus.xml
cat > clickhouse/prometheus.xml << 'EOF'
<clickhouse>
    <prometheus>
        <port>9090</port>
        <endpoint>/api/v1/write</endpoint>
        <table>otel.otel_metrics_v2</table>
        <database>otel</database>
    </prometheus>
</clickhouse>
EOF

# clickhouse/users.xml
cat > clickhouse/users.xml << 'EOF'
<clickhouse>
    <users>
        <default>
            <password></password>
            <networks>
                <ip>::/0</ip>
            </networks>
            <profile>default</profile>
            <quota>default</quota>
            <access_management>1</access_management>
        </default>
    </users>

    <profiles>
        <default>
            <max_memory_usage>10000000000</max_memory_usage>
            <use_uncompressed_cache>0</use_uncompressed_cache>
            <load_balancing>random</load_balancing>
        </default>
    </profiles>

    <quotas>
        <default>
            <interval>
                <duration>3600</duration>
                <queries>0</queries>
                <errors>0</errors>
                <result_rows>0</result_rows>
                <read_rows>0</read_rows>
                <execution_time>0</execution_time>
            </interval>
        </default>
    </quotas>
</clickhouse>
EOF

# ===========================================
# Prometheus Configuration
# ===========================================

# prometheus/prometheus.yml
cat > prometheus/prometheus.yml << 'EOF'
---
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: "main"
    replica: "01"

# Send metrics to ClickHouse via remote write
remote_write:
  - url: "http://clickhouse:9090/api/v1/write"
    queue_config:
      capacity: 10000
      batch_send_deadline: 5s
      max_samples_per_send: 1000
      min_backoff: 100ms
      max_backoff: 30s
    metadata_config:
      send: true
      send_interval: 30s

# Alerting rules
rule_files:
  - "rules.yml"

# Alertmanager configuration
alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - alertmanager:9093

# Scrape targets
scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "node-exporter"
    static_configs:
      - targets: ["node-exporter:9100"]
    scrape_interval: 30s

  - job_name: "clickhouse"
    static_configs:
      - targets: ["clickhouse:8123"]
    metrics_path: /metrics
    scrape_interval: 30s

  - job_name: "hyperdx"
    static_configs:
      - targets: ["hyperdx-ui:3000"]
    metrics_path: /api/metrics
    scrape_interval: 60s

  - job_name: "grafana"
    static_configs:
      - targets: ["grafana:3000"]
    metrics_path: /metrics
    scrape_interval: 60s

EOF

# prometheus/alert_rules.yml
cat > prometheus/rules.yml << 'EOF'
---
groups:
  - name: basic_alerts
    rules:
      - alert: HighCPU
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[2m])) * 100) > 80
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage detected"
          description: "CPU usage is above 80% on instance {{ $labels.instance }}"

      - alert: HighMemory
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage detected"
          description: "Memory usage is above 85% on instance {{ $labels.instance }}"

      - alert: DiskSpaceLow
        expr: (1 - (node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes{fstype!="tmpfs"})) * 100 > 90
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Low disk space"
          description: "Disk usage is above 90% on {{ $labels.instance }} filesystem {{ $labels.mountpoint }}"

      - alert: ClickHouseDown
        expr: up{job="clickhouse"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "ClickHouse is down"
          description: "ClickHouse instance {{ $labels.instance }} is down"

      - alert: PrometheusTargetDown
        expr: up == 0
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Target is down"
          description: "{{ $labels.job }} target {{ $labels.instance }} is down"

EOF

# ===========================================
# AlertManager Configuration
# ===========================================

# alertmanager/alertmanager.yml
cat > alertmanager/alertmanager.yml << 'EOF'
---
global:
  smtp_smarthost: "localhost:587"
  smtp_from: "alertmanager@localhost"
  resolve_timeout: 5m

templates:
  - "/etc/alertmanager/*.tmpl"

route:
  group_by: ["alertname", "cluster", "service"]
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: "default"

receivers:
  - name: "default"

EOF

# ===========================================
# Grafana Configuration
# ===========================================

# grafana/datasources/clickhouse.yml
cat > grafana/datasources/clickhouse.yml << 'EOF'
---
apiVersion: 1

datasources:
  - name: ClickHouse
    type: grafana-clickhouse-datasource
    access: proxy
    url: http://clickhouse:8123
    database: otel
    basicAuth: false
    isDefault: true
    jsonData:
      username: default
      defaultDatabase: otel
      defaultTable: otel_metrics_v2
      timeout: 10
      queryTimeout: 60
      dialTimeout: 10
      debug: false
    secureJsonData:
      password: ""

  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: false
    jsonData:
      timeInterval: "15s"

EOF

# grafana/dashboards/dashboard.yml
cat > grafana/dashboards/dashboard.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'ClickStack'
    orgId: 1
    folder: 'ClickStack'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards

EOF

# grafana/dashboards/clickstack-overview.json
cat > grafana/dashboards/clickstack-overview.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "ClickStack Overview",
    "tags": [
      "clickstack"
    ],
    "style": "dark",
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Metrics Ingestion Rate",
        "type": "stat",
        "targets": [
          {
            "datasource": {
              "type": "grafana-clickhouse-datasource",
              "uid": "clickhouse"
            },
            "rawSql": "SELECT count() FROM otel.otel_metrics_v2 WHERE Timestamp > now() - INTERVAL 1 MINUTE",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {
              "mode": "palette-classic"
            },
            "custom": {
              "hideFrom": {
                "legend": false,
                "tooltip": false,
                "vis": false
              }
            },
            "mappings": [],
            "thresholds": {
              "steps": [
                {
                  "color": "green",
                  "value": null
                },
                {
                  "color": "red",
                  "value": 80
                }
              ]
            }
          }
        },
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 0,
          "y": 0
        }
      },
      {
        "id": 2,
        "title": "Top Metrics by Volume",
        "type": "table",
        "targets": [
          {
            "datasource": {
              "type": "grafana-clickhouse-datasource",
              "uid": "clickhouse"
            },
            "rawSql": "SELECT MetricName, count() as samples FROM otel.otel_metrics_v2 WHERE Timestamp > now() - INTERVAL 1 HOUR GROUP BY MetricName ORDER BY samples DESC LIMIT 10",
            "refId": "A"
          }
        ],
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 12,
          "y": 0
        }
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "timepicker": {},
    "templating": {
      "list": []
    },
    "version": 0
  }
}
EOF

echo "✅ All configuration files created!"
echo ""
echo "📁 Directory structure:"
echo "├── clickhouse/"
echo "│   ├── prometheus.xml"
echo "│   └── users.xml"
echo "├── prometheus/"
echo "│   ├── prometheus.yml"
echo "│   └── alert_rules.yml"
echo "├── alertmanager/"
echo "│   └── alertmanager.yml"
echo "└── grafana/"
echo "    ├── datasources/"
echo "    │   └── clickhouse.yml"
echo "    └── dashboards/"
echo "        ├── dashboard.yml"
echo "        └── clickstack-overview.json"
echo ""
echo "🚀 Now run: docker-compose up -d"