"""Exception fingerprint open/recover edges for registry.exception.recorded."""

import hashlib
from datetime import datetime, timedelta, timezone

from boomerang_contracts.alert.normalized import NormalizedAlert

from kontiki_monitor.alert_mapping import EXCEPTION_RECORDED, _parse_timestamp, _text
from kontiki_monitor.names import KONTIKI_MONITOR_SERVICE_NAME

EXCEPTION_RECOVER_AFTER_SECONDS = 300
EXCEPTION_RECOVER_AFTER_CONFIG_KEY = (
    "%s.exception_recover_after_seconds" % KONTIKI_MONITOR_SERVICE_NAME
)


def exception_short_hash(exception_type, message):
    digest = hashlib.sha256(
        ("%s\0%s" % (exception_type, message)).encode("utf-8")
    ).hexdigest()
    return digest[:12]


def exception_alert_id(service_name, exception_type, message):
    return "exception:%s:%s" % (
        service_name,
        exception_short_hash(exception_type, message),
    )


def _fingerprint_key(service_name, exception_type, message):
    return (service_name, exception_type, message)


class ExceptionFingerprintTracker:
    """Track open exception fingerprints; emit NormalizedAlert on edges only."""

    def __init__(
        self,
        category,
        recover_after_seconds=EXCEPTION_RECOVER_AFTER_SECONDS,
        ttl_hours=None,
        source=KONTIKI_MONITOR_SERVICE_NAME,
    ):
        self._category = category
        self._recover_after = timedelta(seconds=recover_after_seconds)
        self._ttl_hours = ttl_hours
        self._source = source
        self._open = {}

    def observe(self, payload, silenced=None, now=None):
        if not isinstance(payload, dict):
            return []
        if now is None:
            now = datetime.now(timezone.utc)

        silenced_names = set(silenced or [])
        self._drop_silenced(silenced_names)

        service_name = _text(payload.get("service_name"))
        if not service_name or service_name in silenced_names:
            return []

        instance_id = _text(payload.get("instance_id"))
        if not instance_id:
            return []

        exception_type = _text(payload.get("exception_type"))
        message = _text(payload.get("message"))
        occurred_at = _parse_timestamp(payload.get("timestamp"))
        key = _fingerprint_key(service_name, exception_type, message)

        alerts = []
        previous = self._open.get(key)
        if previous is None:
            alert = self._build_alert(
                service_name=service_name,
                instance_id=instance_id,
                exception_type=exception_type,
                message=message,
                occurred_at=occurred_at,
                resolution="open",
            )
            alerts.append(alert)
            self._open[key] = {
                "service_name": service_name,
                "instance_id": instance_id,
                "exception_type": exception_type,
                "message": message,
                "last_seen": now,
                "alert": alert,
            }
        else:
            previous["instance_id"] = instance_id
            previous["last_seen"] = now
        alerts.extend(self.sweep(now=now, skip_key=key))
        return alerts

    def sweep(self, now=None, skip_key=None):
        if now is None:
            now = datetime.now(timezone.utc)
        alerts = []
        for key, state in list(self._open.items()):
            if skip_key is not None and key == skip_key:
                continue
            if now - state["last_seen"] < self._recover_after:
                continue
            alerts.append(
                self._build_alert(
                    service_name=state["service_name"],
                    instance_id=state["instance_id"],
                    exception_type=state["exception_type"],
                    message=state["message"],
                    occurred_at=now,
                    resolution="recovered",
                )
            )
            del self._open[key]
        return alerts

    def drop_service_without_recover(self, service_name):
        name = _text(service_name)
        for key in list(self._open):
            if key[0] == name:
                del self._open[key]

    def list_open_alerts(self):
        alerts = [state["alert"] for state in self._open.values()]
        return sorted(alerts, key=lambda alert: alert.alert_id)

    def _drop_silenced(self, silenced_names):
        for key in list(self._open):
            if key[0] in silenced_names:
                del self._open[key]

    def _build_alert(
        self,
        service_name,
        instance_id,
        exception_type,
        message,
        occurred_at,
        resolution,
    ):
        if resolution == "open":
            severity = "severe"
        else:
            severity = "low"
        title = "%s exception recorded" % service_name
        if exception_type:
            title = "%s %s" % (service_name, exception_type)
        body = message or title
        attributes = {
            "service_name": service_name,
            "instance_id": instance_id,
            "resolution": resolution,
        }
        if exception_type:
            attributes["exception_type"] = exception_type
        expires_at = None
        if self._ttl_hours is not None and self._ttl_hours > 0:
            expires_at = occurred_at + timedelta(hours=self._ttl_hours)
        return NormalizedAlert(
            alert_id=exception_alert_id(service_name, exception_type, message),
            source=self._source,
            category=self._category,
            event_type=EXCEPTION_RECORDED,
            severity=severity,
            occurred_at=occurred_at,
            title=title,
            body=body,
            areas=[],
            attributes=attributes,
            expires_at=expires_at,
        )
