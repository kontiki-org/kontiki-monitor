"""Fleet expectation judgment from Registry.get_services snapshots."""

from datetime import datetime, timedelta, timezone

from boomerang_contracts.alert.normalized import NormalizedAlert
from kontiki_monitor.names import KONTIKI_MONITOR_SERVICE_NAME

CONDITION_MISSING = "missing"
CONDITION_INSUFFICIENT = "insufficient"

EXPECTED_SERVICE_MISSING = "expected_service_missing"
INSUFFICIENT_ACTIVE_INSTANCES = "insufficient_active_instances"

# Default when kontiki-monitor.poll_interval_seconds is set in YAML.
FLEET_POLL_INTERVAL_SECONDS = 30
FLEET_POLL_INTERVAL_CONFIG_KEY = (
    "%s.poll_interval_seconds" % KONTIKI_MONITOR_SERVICE_NAME
)


def parse_expected_services(raw):
    if not isinstance(raw, dict) or not raw:
        return {}
    expected = {}
    for service_name, spec in raw.items():
        name = str(service_name).strip()
        if not name:
            continue
        min_active = 1
        if isinstance(spec, dict) and spec.get("min_active") is not None:
            min_active = int(spec["min_active"])
        if min_active < 1:
            min_active = 1
        expected[name] = min_active
    return expected


def _active_count(instances):
    return sum(
        1
        for data in instances.values()
        if isinstance(data, dict) and data.get("status") == "active"
    )


def _observed_statuses(instances):
    parts = []
    for instance_id in sorted(instances.keys()):
        data = instances[instance_id]
        status = ""
        if isinstance(data, dict):
            status = str(data.get("status") or "")
        parts.append("%s=%s" % (instance_id, status))
    return ",".join(parts)


def _snapshot_for_service(services, service_name):
    raw = services.get(service_name)
    if not isinstance(raw, dict) or not raw:
        return {}
    return raw


class FleetStateTracker:
    """Track open fleet conditions and emit NormalizedAlert on edges only."""

    def __init__(
        self,
        expected_services,
        category,
        ttl_hours=None,
        source=KONTIKI_MONITOR_SERVICE_NAME,
    ):
        self._expected = dict(expected_services)
        self._category = category
        self._ttl_hours = ttl_hours
        self._source = source
        self._open = {}

    def evaluate(self, services, silenced=None):
        if not isinstance(services, dict):
            services = {}
        silenced_names = set(silenced or [])
        for service_name in list(self._open):
            if service_name in silenced_names:
                del self._open[service_name]

        current = self._compute_open(services, silenced_names)
        alerts = []

        for service_name, kind in list(self._open.items()):
            if current.get(service_name) != kind:
                alerts.append(
                    self._build_alert(
                        service_name,
                        kind,
                        services,
                        resolution="recovered",
                    )
                )

        for service_name, kind in current.items():
            if self._open.get(service_name) != kind:
                alerts.append(
                    self._build_alert(
                        service_name,
                        kind,
                        services,
                        resolution="open",
                    )
                )

        self._open = current
        return alerts

    def drop_open_without_recover(self, service_name):
        self._open.pop(service_name, None)

    def _compute_open(self, services, silenced_names=None):
        silenced_names = set(silenced_names or [])
        open_conditions = {}
        for service_name, min_active in self._expected.items():
            if service_name in silenced_names:
                continue
            instances = _snapshot_for_service(services, service_name)
            if not instances:
                open_conditions[service_name] = CONDITION_MISSING
                continue
            if _active_count(instances) < min_active:
                open_conditions[service_name] = CONDITION_INSUFFICIENT
        return open_conditions

    def _build_alert(self, service_name, kind, services, resolution):
        min_active = self._expected[service_name]
        instances = _snapshot_for_service(services, service_name)
        active_count = _active_count(instances) if instances else 0
        observed = _observed_statuses(instances) if instances else ""

        if kind == CONDITION_MISSING:
            event_type = EXPECTED_SERVICE_MISSING
            alert_id = "fleet:%s:missing" % service_name
            if resolution == "open":
                severity = "critical"
                title = "%s missing from registry" % service_name
            else:
                severity = "low"
                title = "%s recovered" % service_name
        else:
            event_type = INSUFFICIENT_ACTIVE_INSTANCES
            alert_id = "fleet:%s:insufficient" % service_name
            if resolution == "open":
                severity = "severe"
                title = "%s insufficient active instances" % service_name
            else:
                severity = "low"
                title = "%s recovered" % service_name

        occurred_at = datetime.now(timezone.utc)
        expires_at = None
        if self._ttl_hours is not None and self._ttl_hours > 0:
            expires_at = occurred_at + timedelta(hours=self._ttl_hours)

        return NormalizedAlert(
            alert_id=alert_id,
            source=self._source,
            category=self._category,
            event_type=event_type,
            severity=severity,
            occurred_at=occurred_at,
            title=title,
            body=title,
            areas=[],
            attributes={
                "service_name": service_name,
                "min_active": min_active,
                "active_count": active_count,
                "observed_statuses": observed,
                "resolution": resolution,
            },
            expires_at=expires_at,
        )
