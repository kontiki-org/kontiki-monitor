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
| `kontiki-monitor.poll_interval_seconds` | *(required)* | Interval in seconds for the fleet poll and the exception-fingerprint recover sweep (Kontiki `@task`). Shipped configs use `30`. |
| `kontiki-monitor.alert_ttl_hours` | unset | Optional TTL hours written on alert `expires_at`. Omit / null → no expiry. |
| `kontiki-monitor.expected_services` | unset (`{}`) | Fleet expectations map. Omit / empty → no fleet poll (lifecycle / exception mapping still runs). |
| `kontiki-monitor.exception_recover_after_seconds` | `300` | After this many seconds without a matching `registry.exception.recorded`, emit `exception_recorded` with `resolution=recovered` for that fingerprint. |
| `kontiki-monitor.silences_path` | `silences.json` (process cwd) | JSON file for on/off silences (same shape as `list_silences`). Missing → empty set; corrupt → fail fast at setup. |
| `kontiki-monitor.sentinel` | unset | Optional external heartbeat. Omit / empty → no POST. See below. |

RPC `list_open_alerts` returns the current open `NormalizedAlert` snapshots
(fleet, exception fingerprints, and the sentinel heartbeat), sorted by
`alert_id`. In-memory only.

Registry lifecycle events (`instance_registered`, `instance_unregistered`,
`instance_state_changed`) map one-to-one to `alert.normalized`.

`registry.exception.recorded` uses a fingerprint
`(service_name, exception_type, message)`: first sight → open
(`alert_id` `exception:{service}:{short_hash}`, `attributes.resolution=open`);
repeats while open → no publish; quiet for
`exception_recover_after_seconds` → recover on the same `alert_id`.

When Messenger `publish` raises Kontiki `AmqpDisconnectedError`, the monitor
and host-check skip that `alert.normalized` attempt (warning only; no raise).

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
  # exception_recover_after_seconds: 300
  expected_services:
    my-api-service:
      min_active: 1
    subscription-service:
      min_active: 1
```

Silences (RPC / HTTP) are runtime state persisted under `silences_path`, not
declared in YAML.

### `kontiki-monitor.sentinel`

Optional block. When present, a heartbeat task calls Registry `get_services`
and, only if that call returns, POSTs an empty body to `url` with
`Authorization: Bearer {token}`. The client timeout is 10 seconds. A 2xx
status is success. Any other status, a connection error, or a timeout is a
failed POST.

A failed `get_services` does not POST and does not count as a failed POST.

| Key | Default | Description |
|-----|---------|-------------|
| `url` | *(required)* | Heartbeat URL. |
| `token` | *(required)* | Bearer token sent on each POST. |
| `interval_seconds` | `60` | Minimum seconds between POSTs. |

Three consecutive failed POSTs publish `sentinel_unreachable` once
(`alert_id` `sentinel:unreachable`, severity `critical`, title
`sentinel unreachable`, `attributes.resolution=open`, `attributes.url` set to
the configured URL). Further failures do not republish. A successful POST
before the third failure clears the streak. The first successful POST while
the alert is open publishes the same `alert_id` with severity `low`, title
`sentinel recovered`, and `attributes.resolution=recovered`.

The subscription catalog exposes this event type with criterion `url`
(`eq`, `contains`).

```yaml
kontiki-monitor:
  sentinel:
    url: https://sentinel.example/watchdogs/prod/heartbeat
    token: "…"
    interval_seconds: 60
```

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

RPC `list_open_alerts` returns open disk snapshots for this instance
(`disk_space_high`, `disk_path_unavailable`), sorted by `alert_id`.

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
