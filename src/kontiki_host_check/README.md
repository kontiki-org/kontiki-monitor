# host-check-service

host-check-service watches disk usage on the paths you choose and publishes `alert.normalized`. Usage at the warning threshold, then critical, opens an alert; a drop recovers it. A path that cannot be measured opens `disk_path_unavailable`. Run one instance per host.

## Configure and run

`host`, `paths`, and `poll_interval_seconds` are required. `host` is the alias stored on the alert. `warning_used_percent` defaults to 90 and `critical_used_percent` to 95. Paths are measured inside the process: mount each host directory on the path listed in the config. Field reference: [configuration](../../docs/configuration.md#host-check-service).

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
