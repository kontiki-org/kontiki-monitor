import logging

from kontiki.configuration.parameter import get_parameter
from kontiki.delegate import ServiceDelegate
from kontiki.registry import ServiceRegistryProxy

from kontiki_monitor.alert_mapping import registry_event_to_normalized_alert
from kontiki_monitor.catalog import REGISTRY_CATEGORY, build_alert_subscription_catalog
from kontiki_monitor.fleet_state import FleetStateTracker, parse_expected_services
from kontiki_monitor.names import KONTIKI_MONITOR_SERVICE_NAME
from kontiki_monitor.silences import SilenceStore


def _service_config(config, key, default=None):
    return get_parameter(config, "%s.%s" % (KONTIKI_MONITOR_SERVICE_NAME, key), default)


class KontikiMonitorDelegate(ServiceDelegate):
    async def setup(self):
        config = self.container.config
        self._category = _service_config(config, "category", REGISTRY_CATEGORY)
        ttl_raw = _service_config(config, "alert_ttl_hours", None)
        self._ttl_hours = float(ttl_raw) if ttl_raw is not None else None
        expected_raw = _service_config(config, "expected_services", None)
        self._expected_services = parse_expected_services(expected_raw)
        self._silences = SilenceStore()
        self._fleet_tracker = None
        if self._expected_services:
            self._fleet_tracker = FleetStateTracker(
                self._expected_services,
                category=self._category,
                ttl_hours=self._ttl_hours,
            )
        logging.info(
            "KontikiMonitorDelegate configured category=%s ttl_hours=%s "
            "expected_services=%s",
            self._category,
            self._ttl_hours,
            sorted(self._expected_services.keys()),
        )

    def get_alert_subscription_catalog(self):
        return build_alert_subscription_catalog(category=self._category)

    def add_silence(self, service_name):
        record = self._silences.add(service_name)
        if self._fleet_tracker is not None:
            self._fleet_tracker.drop_open_without_recover(record["service_name"])
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
