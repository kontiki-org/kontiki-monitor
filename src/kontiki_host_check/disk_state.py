"""Disk occupation judgment from mount usage snapshots."""

import shutil
from datetime import datetime, timedelta, timezone

from boomerang_contracts.alert.normalized import NormalizedAlert
from kontiki_host_check.names import HOST_CHECK_SERVICE_NAME

DISK_SPACE_HIGH = "disk_space_high"

SEVERITY_WARNING = "warning"
SEVERITY_CRITICAL = "critical"

DISK_POLL_INTERVAL_SECONDS = 30
DISK_POLL_INTERVAL_CONFIG_KEY = "host-check.poll_interval_seconds"


def parse_paths(raw):
    if not isinstance(raw, list):
        return []
    paths = []
    for item in raw:
        path = str(item).strip()
        if path:
            paths.append(path)
    return paths


def used_percent_for_path(path):
    usage = shutil.disk_usage(path)
    if usage.total <= 0:
        return 0
    return int((usage.used * 100) / usage.total)


def collect_disk_state(paths, hostname):
    mounts = {}
    for path in paths:
        mounts[path] = {"used_percent": used_percent_for_path(path)}
    return {"hostname": hostname, "mounts": mounts}


def severity_for_usage(used_percent, warning_used_percent, critical_used_percent):
    if used_percent >= critical_used_percent:
        return SEVERITY_CRITICAL
    if used_percent >= warning_used_percent:
        return SEVERITY_WARNING
    return None


class DiskStateTracker:
    """Track open disk conditions per path; emit NormalizedAlert on edges only."""

    def __init__(
        self,
        host,
        paths,
        warning_used_percent,
        critical_used_percent,
        category,
        ttl_hours=None,
        source=HOST_CHECK_SERVICE_NAME,
    ):
        self._host = host
        self._paths = list(paths)
        self._warning_used_percent = int(warning_used_percent)
        self._critical_used_percent = int(critical_used_percent)
        self._category = category
        self._ttl_hours = ttl_hours
        self._source = source
        # path -> severity currently open
        self._open = {}

    def evaluate(self, disk_state):
        if not isinstance(disk_state, dict):
            disk_state = {}
        hostname = str(disk_state.get("hostname") or "").strip()
        mounts = disk_state.get("mounts")
        if not isinstance(mounts, dict):
            mounts = {}

        current = {}
        usage_by_path = {}
        for path in self._paths:
            mount = mounts.get(path)
            used_percent = 0
            if isinstance(mount, dict) and mount.get("used_percent") is not None:
                used_percent = int(mount.get("used_percent"))
            usage_by_path[path] = used_percent
            severity = severity_for_usage(
                used_percent,
                self._warning_used_percent,
                self._critical_used_percent,
            )
            if severity is not None:
                current[path] = severity

        alerts = []

        for path, severity in list(self._open.items()):
            if path not in current:
                alerts.append(
                    self._build_alert(
                        path=path,
                        hostname=hostname,
                        used_percent=usage_by_path.get(path, 0),
                        severity="low",
                        resolution="recovered",
                    )
                )

        for path, severity in current.items():
            previous = self._open.get(path)
            if previous != severity:
                alerts.append(
                    self._build_alert(
                        path=path,
                        hostname=hostname,
                        used_percent=usage_by_path[path],
                        severity=severity,
                        resolution="open",
                    )
                )

        self._open = current
        return alerts

    def _build_alert(self, path, hostname, used_percent, severity, resolution):
        alert_id = "disk:%s:%s" % (self._host, path)
        if resolution == "open":
            title = "%s on %s disk occupation high" % (path, self._host)
        else:
            title = "%s on %s disk occupation recovered" % (path, self._host)

        occurred_at = datetime.now(timezone.utc)
        expires_at = None
        if self._ttl_hours is not None and self._ttl_hours > 0:
            expires_at = occurred_at + timedelta(hours=self._ttl_hours)

        return NormalizedAlert(
            alert_id=alert_id,
            source=self._source,
            category=self._category,
            event_type=DISK_SPACE_HIGH,
            severity=severity,
            occurred_at=occurred_at,
            title=title,
            body=title,
            areas=[],
            attributes={
                "host": self._host,
                "hostname": hostname,
                "path": path,
                "used_percent": used_percent,
                "warning_used_percent": self._warning_used_percent,
                "critical_used_percent": self._critical_used_percent,
                "severity": severity,
                "resolution": resolution,
            },
            expires_at=expires_at,
        )
