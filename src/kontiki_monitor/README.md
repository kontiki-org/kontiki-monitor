# kontiki-monitor

kontiki-monitor watches a Kontiki registry and publishes `alert.normalized`.

A service missing from the fleet, or short of active instances, opens `expected_service_missing` or `insufficient_active_instances`. An instance that registers, leaves, or changes state opens `instance_registered`, `instance_unregistered`, or `instance_state_changed`. The first sight of an exception fingerprint opens `exception_recorded`; a quiet period recovers it. Three failed sentinel heartbeats open `sentinel_unreachable`.

Framework options (`kontiki.*`) are documented with Kontiki. Restart the service after a YAML change.

## `kontiki-monitor`

| Key | Default | Description |
|-----|---------|-------------|
| `kontiki-monitor.category` | `kontiki.registry` | Alert category on `alert.normalized`, and in the subscription catalog. |
| `kontiki-monitor.poll_interval_seconds` | *(required)* | Seconds between the fleet poll and the exception-fingerprint recover sweep. Shipped configs use `30`. |
| `kontiki-monitor.alert_ttl_hours` | unset | TTL hours written on `expires_at`. Omit or null leaves alerts without an expiry. |
| `kontiki-monitor.expected_services` | `{}` | Fleet expectations. An empty map leaves the fleet poll off. Lifecycle and exception alerts still run. |
| `kontiki-monitor.exception_recover_after_seconds` | `300` | Quiet seconds before `exception_recorded` is published again with `resolution=recovered`. |
| `kontiki-monitor.silences_path` | `silences.json` | JSON file of silences, in the process directory. A missing file is an empty set. A corrupt file fails setup. |
| `kontiki-monitor.sentinel` | unset | External heartbeat. Omit the block and no POST runs. |

```yaml
kontiki-monitor:
  category: kontiki.registry
  poll_interval_seconds: 30
  expected_services:
    my-api-service:
      min_active: 1
```

RPC `list_open_alerts` returns the open fleet, exception, and sentinel snapshots, sorted by `alert_id`. In memory only.

Lifecycle events map one-to-one onto `alert.normalized`. `registry.exception.recorded` is fingerprinted on `(service_name, exception_type, message)`. The first sight opens `alert_id` `exception:{service}:{short_hash}` with `attributes.resolution=open`. Repeats while that alert is open stay quiet. After `exception_recover_after_seconds` the same `alert_id` recovers.

When `publish` raises `AmqpDisconnectedError`, that `alert.normalized` attempt is skipped.

Silences are runtime state under `silences_path`, added and cleared over RPC or HTTP. They are kept across restarts.

### `kontiki-monitor.expected_services`

Map of Registry service name → spec.

| Field | Required | Description |
|-------|----------|-------------|
| *(key)* | yes | Exact Registry service name. |
| `min_active` | no | Minimum instances with `status: active`. Default `1`. |

A missing service emits `expected_service_missing`. Too few active instances emit `insufficient_active_instances`. Each edge is published once.

### `kontiki-monitor.sentinel`

When the block is present, a task calls Registry `get_services` and, only if that call returns, POSTs an empty body to `url` with `Authorization: Bearer {token}`. The client timeout is 10 seconds. A 2xx status is success. Any other status, a connection error, or a timeout is a failed POST. A failed `get_services` does not POST and does not count as a failed POST.

| Key | Default | Description |
|-----|---------|-------------|
| `url` | *(required)* | Heartbeat URL. |
| `token` | *(required)* | Bearer token on each POST. |
| `interval_seconds` | `60` | Minimum seconds between POSTs. |

Three consecutive failed POSTs publish `sentinel_unreachable` once (`alert_id` `sentinel:unreachable`, severity `critical`, `attributes.resolution=open`, `attributes.sentinel_url` set to `url`). Further failures stay quiet. A successful POST before the third failure clears the streak. The first success while the alert is open publishes the same `alert_id` at severity `low`, with `attributes.resolution=recovered`. The subscription catalog exposes criterion `sentinel_url` (`eq`, `contains`).

```yaml
kontiki-monitor:
  sentinel:
    url: https://sentinel.example/watchdogs/prod/heartbeat
    token: "change-me"
    interval_seconds: 60
```

## Run

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
