import logging
import time

from kontiki.configuration.parameter import get_parameter
from kontiki.delegate import ServiceDelegate
from kontiki.registry import ServiceRegistryProxy

from kontiki_monitor.alert_mapping import registry_event_to_normalized_alert
from kontiki_monitor.catalog import REGISTRY_CATEGORY, build_alert_subscription_catalog
from kontiki_monitor.exception_fingerprint import (
    EXCEPTION_RECOVER_AFTER_SECONDS,
    ExceptionFingerprintTracker,
)
from kontiki_monitor.fleet_state import FleetStateTracker, parse_expected_services
from kontiki_monitor.sentinel import (
    DEFAULT_SENTINEL_INTERVAL_SECONDS,
    SentinelHeartbeat,
    send_heartbeat,
)
from kontiki_monitor.silences import DEFAULT_SILENCES_PATH, SilenceStore


def _silences_path(config):
    raw = get_parameter(config, "kontiki-monitor.silences_path", DEFAULT_SILENCES_PATH)
    if raw is None:
        return DEFAULT_SILENCES_PATH
    text = str(raw).strip()
    if not text:
        return DEFAULT_SILENCES_PATH
    return text


class KontikiMonitorDelegate(ServiceDelegate):
    async def setup(self):
        config = self.container.config
        self._category = get_parameter(
            config, "kontiki-monitor.category", REGISTRY_CATEGORY
        )
        ttl_raw = get_parameter(config, "kontiki-monitor.alert_ttl_hours", None)
        self._ttl_hours = float(ttl_raw) if ttl_raw is not None else None
        expected_raw = get_parameter(config, "kontiki-monitor.expected_services", None)
        self._expected_services = parse_expected_services(expected_raw)
        recover_raw = get_parameter(
            config,
            "kontiki-monitor.exception_recover_after_seconds",
            EXCEPTION_RECOVER_AFTER_SECONDS,
        )
        self._exception_recover_after_seconds = int(recover_raw)
        self._silences_path = _silences_path(config)
        self._silences = SilenceStore(self._silences_path)
        self._fleet_tracker = None
        if self._expected_services:
            self._fleet_tracker = FleetStateTracker(
                self._expected_services,
                category=self._category,
                ttl_hours=self._ttl_hours,
            )
        self._exception_tracker = ExceptionFingerprintTracker(
            category=self._category,
            recover_after_seconds=self._exception_recover_after_seconds,
            ttl_hours=self._ttl_hours,
        )
        sentinel = get_parameter(config, "kontiki-monitor.sentinel", None)
        self._sentinel = None
        self._sentinel_interval = None
        self._sentinel_not_before = 0.0
        if sentinel:
            self._sentinel = SentinelHeartbeat(
                get_parameter(config, "kontiki-monitor.sentinel.url"),
                get_parameter(config, "kontiki-monitor.sentinel.token"),
                category=self._category,
                ttl_hours=self._ttl_hours,
            )
            self._sentinel_interval = get_parameter(
                config,
                "kontiki-monitor.sentinel.interval_seconds",
                DEFAULT_SENTINEL_INTERVAL_SECONDS,
            )
        logging.info(
            "KontikiMonitorDelegate configured category=%s ttl_hours=%s "
            "expected_services=%s exception_recover_after_seconds=%s "
            "silences_path=%s sentinel=%s",
            self._category,
            self._ttl_hours,
            sorted(self._expected_services.keys()),
            self._exception_recover_after_seconds,
            self._silences_path,
            None if self._sentinel is None else self._sentinel.url,
        )

    def get_alert_subscription_catalog(self):
        return build_alert_subscription_catalog(category=self._category)

    def add_silence(self, service_name):
        record = self._silences.add(service_name)
        if self._fleet_tracker is not None:
            self._fleet_tracker.drop_open_without_recover(record["service_name"])
        self._exception_tracker.drop_service_without_recover(record["service_name"])
        logging.info("Silence added for service_name=%s", record["service_name"])
        return record

    def clear_silence(self, service_name):
        result = self._silences.clear(service_name)
        logging.info(
            "Silence clear for service_name=%s cleared=%s",
            service_name,
            result.get("cleared"),
        )
        return result

    def list_silences(self):
        return self._silences.list()

    def list_open_alerts(self):
        alerts = []
        if self._fleet_tracker is not None:
            alerts.extend(self._fleet_tracker.list_open_alerts())
        alerts.extend(self._exception_tracker.list_open_alerts())
        if self._sentinel is not None:
            alerts.extend(self._sentinel.list_open_alerts())
        return sorted(alerts, key=lambda alert: alert.alert_id)

    def build_normalized_alert(self, registry_event_type, payload):
        if not isinstance(payload, dict):
            logging.warning(
                "Ignoring registry event %s with non-dict payload: %r",
                registry_event_type,
                payload,
            )
            return None
        service_name = payload.get("service_name")
        if self._silences.is_silenced(service_name):
            logging.info(
                "Dropping registry event %s for silenced service_name=%s",
                registry_event_type,
                service_name,
            )
            return None
        alert = registry_event_to_normalized_alert(
            registry_event_type,
            payload,
            category=self._category,
            ttl_hours=self._ttl_hours,
        )
        if alert is None:
            logging.warning(
                "Ignoring unsupported or invalid registry event %s payload=%s",
                registry_event_type,
                payload,
            )
        return alert

    def observe_exception_recorded(self, payload):
        return self._exception_tracker.observe(payload, silenced=self._silences.names())

    def sweep_exception_fingerprints(self):
        return self._exception_tracker.sweep()

    async def build_fleet_alerts(self):
        if self._fleet_tracker is None:
            return []
        messenger = self.container.service_instance.messenger
        try:
            services = await ServiceRegistryProxy(messenger).get_services()
        except Exception:
            logging.exception(
                "Fleet poll failed calling ServiceRegistry.get_services; skipping cycle"
            )
            return []
        return self._fleet_tracker.evaluate(services, silenced=self._silences.names())

    async def poll_sentinel_heartbeat(self):
        if self._sentinel is None:
            return []
        now = time.monotonic()
        if now < self._sentinel_not_before:
            return []
        self._sentinel_not_before = now + self._sentinel_interval
        messenger = self.container.service_instance.messenger
        try:
            await ServiceRegistryProxy(messenger).get_services()
        except Exception as exc:
            logging.warning(
                "Sentinel heartbeat skipped; ServiceRegistry.get_services failed: %s",
                exc,
            )
            return []
        post_ok = await send_heartbeat(self._sentinel.url, self._sentinel.token)
        return self._sentinel.observe(post_ok)
