"""Disk occupation and path-availability judgment from mount snapshots."""

import shutil
from datetime import datetime, timedelta, timezone

from boomerang_contracts.alert.normalized import NormalizedAlert
from kontiki_host_check.names import HOST_CHECK_SERVICE_NAME

DISK_SPACE_HIGH = "disk_space_high"
DISK_PATH_UNAVAILABLE = "disk_path_unavailable"

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


def _os_error_message(exc):
    strerror = exc.strerror
    if strerror:
        return str(strerror).strip()
    return str(exc).strip()


def collect_disk_state(paths, hostname):
    mounts = {}
    for path in paths:
        try:
            mounts[path] = {"used_percent": used_percent_for_path(path)}
        except OSError as exc:
            mounts[path] = {"error": _os_error_message(exc)}
    return {"hostname": hostname, "mounts": mounts}


def severity_for_usage(used_percent, warning_used_percent, critical_used_percent):
    if used_percent >= critical_used_percent:
        return SEVERITY_CRITICAL
    if used_percent >= warning_used_percent:
        return SEVERITY_WARNING
    return None


def _mount_error(mount):
    if not isinstance(mount, dict):
        return None
    error = mount.get("error")
    if error is None:
        return None
    text = str(error).strip()
    if not text:
        return None
    return text


def _mount_used_percent(mount):
    if not isinstance(mount, dict):
        return 0
    if mount.get("used_percent") is None:
        return 0
    return int(mount.get("used_percent"))


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
        # path -> severity for disk_space_high
        self._open_high = {}
        # path -> last error text for disk_path_unavailable
        self._open_unavailable = {}

    def evaluate(self, disk_state):
        if not isinstance(disk_state, dict):
            disk_state = {}
        hostname = str(disk_state.get("hostname") or "").strip()
        mounts = disk_state.get("mounts")
        if not isinstance(mounts, dict):
            mounts = {}

        current_high = {}
        current_unavailable = {}
        usage_by_path = {}
        error_by_path = {}

        for path in self._paths:
            mount = mounts.get(path)
            error = _mount_error(mount)
            if error is not None:
                current_unavailable[path] = error
                error_by_path[path] = error
                usage_by_path[path] = 0
                continue
            used_percent = _mount_used_percent(mount)
            usage_by_path[path] = used_percent
            error_by_path[path] = ""
            severity = severity_for_usage(
                used_percent,
                self._warning_used_percent,
                self._critical_used_percent,
            )
            if severity is not None:
                current_high[path] = severity

        alerts = []

        # High recover first when path leaves high (including -> unavailable).
        for path in list(self._open_high):
            if path not in current_high:
                alerts.append(
                    self._build_high_alert(
                        path=path,
                        hostname=hostname,
                        used_percent=usage_by_path.get(path, 0),
                        severity="low",
                        resolution="recovered",
                    )
                )

        # Unavailable recover when path becomes readable again.
        for path in list(self._open_unavailable):
            if path not in current_unavailable:
                alerts.append(
                    self._build_unavailable_alert(
                        path=path,
                        hostname=hostname,
                        error="",
                        severity="low",
                        resolution="recovered",
                    )
                )

        # High open / severity change (only for readable paths).
        for path, severity in current_high.items():
            previous = self._open_high.get(path)
            if previous != severity:
                alerts.append(
                    self._build_high_alert(
                        path=path,
                        hostname=hostname,
                        used_percent=usage_by_path[path],
                        severity=severity,
                        resolution="open",
                    )
                )

        # Unavailable open (no re-publish while still unavailable).
        for path, error in current_unavailable.items():
            if path not in self._open_unavailable:
                alerts.append(
                    self._build_unavailable_alert(
                        path=path,
                        hostname=hostname,
                        error=error,
                        severity=SEVERITY_CRITICAL,
                        resolution="open",
                    )
                )

        self._open_high = current_high
        self._open_unavailable = current_unavailable
        return alerts

    def _expires_at(self, occurred_at):
        if self._ttl_hours is not None and self._ttl_hours > 0:
            return occurred_at + timedelta(hours=self._ttl_hours)
        return None

    def _build_high_alert(self, path, hostname, used_percent, severity, resolution):
        alert_id = "disk:%s:%s" % (self._host, path)
        if resolution == "open":
            title = "%s on %s disk occupation high" % (path, self._host)
        else:
            title = "%s on %s disk occupation recovered" % (path, self._host)

        occurred_at = datetime.now(timezone.utc)
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
            expires_at=self._expires_at(occurred_at),
        )

    def _build_unavailable_alert(self, path, hostname, error, severity, resolution):
        alert_id = "disk:%s:%s:unavailable" % (self._host, path)
        if resolution == "open":
            title = "%s on %s disk path unavailable" % (path, self._host)
        else:
            title = "%s on %s disk path recovered" % (path, self._host)

        occurred_at = datetime.now(timezone.utc)
        return NormalizedAlert(
            alert_id=alert_id,
            source=self._source,
            category=self._category,
            event_type=DISK_PATH_UNAVAILABLE,
            severity=severity,
            occurred_at=occurred_at,
            title=title,
            body=title,
            areas=[],
            attributes={
                "host": self._host,
                "hostname": hostname,
                "path": path,
                "error": error,
                "severity": severity,
                "resolution": resolution,
            },
            expires_at=self._expires_at(occurred_at),
        )
