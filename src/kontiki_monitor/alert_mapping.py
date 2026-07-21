from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any

from boomerang_contracts.alert.normalized import NormalizedAlert

from kontiki_monitor.catalog import REGISTRY_CATEGORY
from kontiki_monitor.names import KONTIKI_MONITOR_SERVICE_NAME

INSTANCE_REGISTERED = "instance_registered"
INSTANCE_UNREGISTERED = "instance_unregistered"
INSTANCE_STATE_CHANGED = "instance_state_changed"
EXCEPTION_RECORDED = "exception_recorded"

REGISTRY_EVENT_INSTANCE_REGISTERED = "registry.instance.registered"
REGISTRY_EVENT_INSTANCE_DEREGISTERED = "registry.instance.deregistered"
REGISTRY_EVENT_INSTANCE_STATUS_CHANGED = "registry.instance.status_changed"
REGISTRY_EVENT_EXCEPTION_RECORDED = "registry.exception.recorded"


def _parse_timestamp(value: object) -> datetime:
    if isinstance(value, datetime):
        if value.tzinfo is None:
            return value.replace(tzinfo=timezone.utc)
        return value
    if isinstance(value, str):
        text = value.strip()
        if text.endswith("Z"):
            text = text[:-1] + "+00:00"
        parsed = datetime.fromisoformat(text)
        if parsed.tzinfo is None:
            return parsed.replace(tzinfo=timezone.utc)
        return parsed
    return datetime.now(timezone.utc)


def _text(value: object) -> str:
    if value is None:
        return ""
    return str(value).strip()


def _severity_for_state_change(previous_state: str, new_state: str) -> str:
    new = new_state.lower()
    if new == "down":
        return "critical"
    if new == "degraded":
        return "severe"
    if new == "active" and previous_state.lower() in {"degraded", "down"}:
        return "low"
    return "moderate"


def _build_alert(
    *,
    category: str,
    event_type: str,
    alert_id: str,
    severity: str,
    occurred_at: datetime,
    title: str,
    body: str,
    attributes: dict[str, Any],
    ttl_hours: float | None,
) -> NormalizedAlert:
    expires_at = None
    if ttl_hours is not None and ttl_hours > 0:
        expires_at = occurred_at + timedelta(hours=ttl_hours)
    return NormalizedAlert(
        alert_id=alert_id,
        source=KONTIKI_MONITOR_SERVICE_NAME,
        category=category,
        event_type=event_type,
        severity=severity,
        occurred_at=occurred_at,
        title=title,
        body=body,
        areas=[],
        attributes=attributes,
        expires_at=expires_at,
    )


def registry_event_to_normalized_alert(
    registry_event_type: str,
    payload: dict[str, Any],
    *,
    category: str = REGISTRY_CATEGORY,
    ttl_hours: float | None = None,
) -> NormalizedAlert | None:
    if not isinstance(payload, dict):
        return None

    service_name = _text(payload.get("service_name"))
    instance_id = _text(payload.get("instance_id"))
    if not service_name or not instance_id:
        return None

    occurred_at = _parse_timestamp(payload.get("timestamp"))
    event_key = (registry_event_type or "").strip().lower()

    if event_key == REGISTRY_EVENT_INSTANCE_REGISTERED:
        host = _text(payload.get("host"))
        version = _text(payload.get("service_version"))
        attributes = {
            "service_name": service_name,
            "instance_id": instance_id,
        }
        if host:
            attributes["host"] = host
        if version:
            attributes["version"] = version
        title = f"{service_name} instance registered"
        if host:
            title = f"{title} on {host}"
        body = title
        if version:
            body = f"{body} (version {version})."
        return _build_alert(
            category=category,
            event_type=INSTANCE_REGISTERED,
            alert_id=(
                f"registry:{service_name}:{instance_id}:registered:"
                f"{occurred_at.isoformat()}"
            ),
            severity="low",
            occurred_at=occurred_at,
            title=title,
            body=body,
            attributes=attributes,
            ttl_hours=ttl_hours,
        )

    if event_key == REGISTRY_EVENT_INSTANCE_DEREGISTERED:
        attributes = {
            "service_name": service_name,
            "instance_id": instance_id,
        }
        title = f"{service_name} instance unregistered"
        return _build_alert(
            category=category,
            event_type=INSTANCE_UNREGISTERED,
            alert_id=(
                f"registry:{service_name}:{instance_id}:unregistered:"
                f"{occurred_at.isoformat()}"
            ),
            severity="low",
            occurred_at=occurred_at,
            title=title,
            body=title,
            attributes=attributes,
            ttl_hours=ttl_hours,
        )

    if event_key == REGISTRY_EVENT_INSTANCE_STATUS_CHANGED:
        previous_state = _text(payload.get("previous_status"))
        new_state = _text(payload.get("new_status"))
        if not previous_state or not new_state:
            return None
        attributes = {
            "service_name": service_name,
            "instance_id": instance_id,
            "previous_state": previous_state,
            "new_state": new_state,
        }
        title = f"{service_name} state {previous_state} → {new_state}"
        body = f"Instance {instance_id} changed from {previous_state} to {new_state}."
        return _build_alert(
            category=category,
            event_type=INSTANCE_STATE_CHANGED,
            alert_id=(
                f"registry:{service_name}:{instance_id}:state:"
                f"{previous_state}:{new_state}:{occurred_at.isoformat()}"
            ),
            severity=_severity_for_state_change(previous_state, new_state),
            occurred_at=occurred_at,
            title=title,
            body=body,
            attributes=attributes,
            ttl_hours=ttl_hours,
        )

    if event_key == REGISTRY_EVENT_EXCEPTION_RECORDED:
        exception_type = _text(payload.get("exception_type"))
        message = _text(payload.get("message"))
        attributes = {
            "service_name": service_name,
            "instance_id": instance_id,
        }
        if exception_type:
            attributes["exception_type"] = exception_type
        title = f"{service_name} exception recorded"
        if exception_type:
            title = f"{service_name} {exception_type}"
        body = message or title
        return _build_alert(
            category=category,
            event_type=EXCEPTION_RECORDED,
            alert_id=(
                f"registry:{service_name}:{instance_id}:exception:"
                f"{occurred_at.isoformat()}"
            ),
            severity="severe",
            occurred_at=occurred_at,
            title=title,
            body=body,
            attributes=attributes,
            ttl_hours=ttl_hours,
        )

    return None
