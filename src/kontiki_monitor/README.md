# kontiki-monitor

kontiki-monitor watches a Kontiki registry and publishes `alert.normalized`. A short fleet, an instance that registers, leaves, or changes state, a new exception fingerprint, and a failed sentinel heartbeat each open an alert. The matching recovery closes it.

## Configure and run

`poll_interval_seconds` is required. `expected_services` maps a Registry service name to `min_active` (default 1). An empty map leaves the fleet poll off; lifecycle and exception alerts still run. Restart the service after a change. `sentinel` POSTs a heartbeat only after Registry `get_services` returns. Silences persist in `silences_path` (default `silences.json` in the process directory). Field reference: [configuration](../../docs/configuration.md#kontiki-monitor).

```yaml
kontiki-monitor:
  category: kontiki.registry
  poll_interval_seconds: 30
  expected_services:
    my-api-service:
      min_active: 1
```

RabbitMQ and the registry come from `stack/common.services.yaml`. `config/default.yaml` is the service file. `config/embedded.yaml` adds the demo fleet and HTTP silences on port 8091.

```bash
docker run --rm \
  -v "$PWD/stack:/stack:ro" \
  -v "$PWD/config:/config:ro" \
  ghcr.io/kontiki-org/kontiki-monitor:1.0.0 \
  --config /stack/common.services.yaml \
  --config /config/default.yaml \
  --config /config/embedded.yaml
```

From a checkout:

```bash
poetry run kontiki-monitor \
  --config stack/common.services.yaml \
  --config config/default.yaml \
  --config config/embedded.yaml
```
