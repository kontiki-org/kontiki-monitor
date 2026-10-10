# host-check-service

host-check-service watches disk usage on the paths you choose and publishes `alert.normalized`. Usage at the warning threshold, then critical, opens `disk_space_high`; a drop recovers it. A path that cannot be measured opens `disk_path_unavailable`. Run one instance per host.

Framework options (`kontiki.*`) are documented with Kontiki. Restart the service after a YAML change. Paths are measured inside the process: mount each host directory on the path listed in the config.

## `host-check`

| Key | Default | Description |
|-----|---------|-------------|
| `host-check.host` | *(required)* | Stable alias stored on the alert and used in `alert_id`. |
| `host-check.paths` | *(required)* | Non-empty list of absolute paths to measure. |
| `host-check.warning_used_percent` | `90` | Used-percent threshold for severity `warning` (`1..100`). |
| `host-check.critical_used_percent` | `95` | Used-percent threshold for severity `critical`. Must be at least `warning_used_percent`. |
| `host-check.category` | `kontiki.host` | Alert category on `alert.normalized`. |
| `host-check.poll_interval_seconds` | *(required)* | Seconds between disk polls. Shipped configs use `30`. |
| `host-check.alert_ttl_hours` | unset | TTL hours written on `expires_at`. Omit or null leaves alerts without an expiry. |

```yaml
host-check:
  host: local
  category: kontiki.host
  poll_interval_seconds: 30
  warning_used_percent: 90
  critical_used_percent: 95
  paths:
    - /
```

RPC `list_open_alerts` returns the open disk snapshots for this instance (`disk_space_high`, `disk_path_unavailable`), sorted by `alert_id`.

When `publish` raises `AmqpDisconnectedError`, that `alert.normalized` attempt is skipped.

## Run

RabbitMQ and the registry come from `stack/common.services.yaml`.

```bash
docker run --rm \
  -v "$PWD/stack:/stack:ro" \
  -v "$PWD/config:/config:ro" \
  ghcr.io/kontiki-org/host-check-service:1.0.0 \
  --config /stack/common.services.yaml \
  --config /config/host-check.yaml
```

From a checkout:

```bash
poetry run host-check-service \
  --config stack/common.services.yaml \
  --config config/host-check.yaml
```
