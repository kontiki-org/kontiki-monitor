# kontiki-monitor configuration reference

Services in this package are Kontiki services. Framework options live under
**`kontiki`** (see Kontiki’s `docs/configuration.md`). Application settings use
service-specific top-level keys:

| Service | CLI | Config prefix |
|---------|-----|---------------|
| `kontiki-monitor` | `kontiki-monitor` | `kontiki-monitor:` |
| `host-check-service` | `host-check-service` | `host-check:` |

Each process loads **its own** YAML via `--config` (Compose may merge several
files). Keys below apply only to the service that reads them.

An annotated example covering every application option is in
[kontiki-monitor-config.example.yaml](kontiki-monitor-config.example.yaml).
Runtime files used by the ops stack live under [`config/`](../config/) and
[`stack/`](../stack/).

---

## kontiki-monitor

| Key | Default | Description |
|-----|---------|-------------|
| `kontiki-monitor.category` | `kontiki.registry` | Alert category published on `alert.normalized` (also used in the subscription catalog). |
| `kontiki-monitor.poll_interval_seconds` | *(required)* | Fleet poll interval in seconds (Kontiki `@task`). Shipped configs use `30`. |
| `kontiki-monitor.alert_ttl_hours` | unset | Optional TTL hours written on alert `expires_at`. Omit / null → no expiry. |
| `kontiki-monitor.expected_services` | unset (`{}`) | Fleet expectations map. Omit / empty → no fleet poll (lifecycle / exception mapping still runs). |

### `kontiki-monitor.expected_services`

Map **service_name → spec**. Restart after changes.

| Field | Required | Description |
|-------|----------|-------------|
| *(key)* | yes | Exact Registry service name to expect. |
| `min_active` | no | Minimum instances with `status: active` (default `1`, clamped to ≥ 1). |

When a service is missing or has too few active instances, the monitor emits
`expected_service_missing` / `insufficient_active_instances` (edges only).

Example:

```yaml
kontiki-monitor:
  category: kontiki.registry
  poll_interval_seconds: 30
  expected_services:
    my-api-service:
      min_active: 1
    subscription-service:
      min_active: 1
```

Silences (RPC / HTTP) are runtime state, not YAML.

---

## host-check-service

| Key | Default | Description |
|-----|---------|-------------|
| `host-check.host` | *(required)* | Stable alias for subscriptions / `alert_id` (not necessarily the OS hostname). |
| `host-check.paths` | *(required)* | Non-empty list of absolute paths to measure (`shutil.disk_usage`). |
| `host-check.warning_used_percent` | `90` | Used-% threshold for severity warning (`1..100`). |
| `host-check.critical_used_percent` | `95` | Used-% threshold for severity critical; must be `>= warning_used_percent`. |
| `host-check.category` | `kontiki.host` | Alert category on `alert.normalized`. |
| `host-check.poll_interval_seconds` | *(required)* | Disk poll interval in seconds (Kontiki `@task`). Shipped configs use `30`. |
| `host-check.alert_ttl_hours` | unset | Optional TTL hours on `expires_at`. Omit / null → no expiry. |

Example:

```yaml
host-check:
  host: "local"
  category: kontiki.host
  poll_interval_seconds: 30
  warning_used_percent: 90
  critical_used_percent: 95
  paths:
    - /
```

Run **one instance per host** (or mount namespace) you want to watch.
