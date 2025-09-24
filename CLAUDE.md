# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ClickStack is a complete observability stack built around ClickHouse as the primary time-series database. It integrates Prometheus for metrics collection, Grafana for visualization, HyperDX for observability UI, and AlertManager for alerting.

## Architecture

The system consists of 7 containerized services orchestrated by Docker Compose:

- **ClickHouse** (port 8123/9000/9091): Primary time-series database using TimeSeries table engine for native Prometheus remote_write support
- **MongoDB** (internal): State storage for HyperDX UI
- **HyperDX UI** (port 8080): Main observability interface and frontend with OpenTelemetry endpoints (4317/4318)
- **Prometheus** (port 9090): Metrics collection with true remote_write integration to ClickHouse
- **Grafana** (port 3000): Visualization layer with ClickHouse and Prometheus datasources
- **AlertManager** (port 9093): Alert processing and routing
- **Node Exporter** (port 9100): System metrics collection (WSL2-optimized collectors)

The data flow follows: Node Exporter → Prometheus → ClickHouse (TimeSeries) ← Grafana/HyperDX.

## Configuration Structure

Each service has its configuration directory:

- `clickhouse/`: ClickHouse XML configuration files and SQL initialization scripts
- `prometheus/`: Prometheus config and alert rules
- `alertmanager/`: AlertManager routing configuration
- `grafana/`: Grafana datasource definitions and dashboard provisioning

## Common Commands

### Development Setup

```bash
# Start the complete stack
docker-compose up -d

# View logs for specific service
docker-compose logs -f <service_name>

# Stop the stack
docker-compose down

# Stop and remove volumes (clean slate)
docker-compose down -v
```

### Configuration Management

```bash
# Validate YAML configurations
yamllint .

# Check spelling in documentation
cspell "**/*.md"

# Reload Prometheus configuration (without restart)
curl -X POST http://localhost:9090/-/reload
```

### Service Access

- HyperDX UI: `http://localhost:8080` (main interface)
- Grafana: `http://localhost:3000` (admin/admin)
- Prometheus: `http://localhost:9090`
- AlertManager: `http://localhost:9093`
- ClickHouse HTTP: `http://localhost:8123`
- ClickHouse Prometheus Write: `http://localhost:9091`

## Configuration Patterns

- All services use the `clickstack` Docker network for internal communication
- ClickHouse automatically initializes with `otel` database and TimeSeries table via `clickhouse/init.sql`
- ClickHouse provides Prometheus remote write endpoint on port 9091 configured via `clickhouse/prometheus.xml`
- ClickHouse uses TimeSeries table engine (experimental) for native Prometheus remote_write support
- Node-exporter configured with WSL2-compatible collectors (netstat/softnet disabled)
- Grafana has both ClickHouse (default) and Prometheus datasources configured
- Alert rules are defined in `prometheus/rules.yml` with basic system monitoring
- Prometheus remote write sends all metrics to ClickHouse for long-term storage

## Key Files

- `docker-compose.yaml`: Complete service orchestration and port mappings
- `clickhouse/init.sql`: ClickHouse database and TimeSeries table initialization (simplified 13-line script)
- `clickhouse/prometheus.xml`: Prometheus remote write endpoint configuration with proper handler naming
- `clickhouse/timeseries.xml`: Enables experimental TimeSeries table engine
- `clickhouse/users.xml`: User authentication with network access permissions
- `prometheus/prometheus.yml`: Scrape targets and remote write configuration with authentication
- `grafana/datasources/clickhouse.yml`: ClickHouse datasource connection details

## Troubleshooting

### Common Issues and Fixes

#### TimeSeries Table Issues
- **Problem**: "Table otel.prometheus does not exist" errors in Prometheus logs
- **Solution**: Ensure handler names in `clickhouse/prometheus.xml` use unique identifiers (e.g., `<prometheus_write>` not `<write_handler>`)
- **Verification**: Check table exists with `docker-compose exec clickhouse clickhouse-client -q "SHOW TABLES FROM otel"`

#### Node-exporter Network Statistics Errors
- **Problem**: "collector failed" errors for netstat/softnet in WSL2/Docker environments
- **Solution**: Disable problematic collectors with `--no-collector.netstat` and `--no-collector.softnet` flags
- **Status**: Already configured in docker-compose.yaml

#### ClickHouse Remote Write Authentication
- **Problem**: "Authentication failed" errors when testing remote_write endpoint
- **Solution**: Ensure users.xml allows network access from containers (`<ip>0.0.0.0/0</ip>`)
- **Test**: `curl -u "clickstack_user:PCqt82oOlksMNr9PjDmhLBJOP" http://localhost:9091/api/v1/write`

### Required ClickHouse Settings
```xml
<!-- Enable TimeSeries experimental feature -->
<allow_experimental_time_series_table>1</allow_experimental_time_series_table>
```

### TimeSeries Table Structure
The `otel.prometheus` table uses ClickHouse's experimental TimeSeries engine:
```sql
CREATE DATABASE IF NOT EXISTS otel;
SET allow_experimental_time_series_table = 1;
CREATE TABLE IF NOT EXISTS otel.prometheus ENGINE = TimeSeries;
```
