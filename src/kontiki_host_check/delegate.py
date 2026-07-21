import logging
import socket

from kontiki.configuration.parameter import get_parameter
from kontiki.delegate import ServiceDelegate

from kontiki_host_check.catalog import HOST_CATEGORY, build_alert_subscription_catalog
from kontiki_host_check.disk_state import (
    DiskStateTracker,
    collect_disk_state,
    parse_paths,
)
from kontiki_host_check.names import HOST_CHECK_CONFIG_PREFIX


def _service_config(config, key, default=None):
    return get_parameter(config, "%s.%s" % (HOST_CHECK_CONFIG_PREFIX, key), default)


class HostCheckDelegate(ServiceDelegate):
    async def setup(self):
        config = self.container.config
        host = str(_service_config(config, "host", "") or "").strip()
        if not host:
            raise ValueError("host-check.host is required")
        paths = parse_paths(_service_config(config, "paths", None))
        if not paths:
            raise ValueError("host-check.paths must list at least one path")
        warning = _service_config(config, "warning_used_percent", 90)
        critical = _service_config(config, "critical_used_percent", 95)
        warning = int(warning)
        critical = int(critical)
        if warning < 1 or warning > 100:
            raise ValueError("host-check.warning_used_percent must be 1..100")
        if critical < 1 or critical > 100:
            raise ValueError("host-check.critical_used_percent must be 1..100")
        if critical < warning:
            raise ValueError(
                "host-check.critical_used_percent must be >= warning_used_percent"
            )
        self._category = _service_config(config, "category", HOST_CATEGORY)
        ttl_raw = _service_config(config, "alert_ttl_hours", None)
        self._ttl_hours = float(ttl_raw) if ttl_raw is not None else None
        self._paths = paths
        self._tracker = DiskStateTracker(
            host=host,
            paths=paths,
            warning_used_percent=warning,
            critical_used_percent=critical,
            category=self._category,
            ttl_hours=self._ttl_hours,
        )
        logging.info(
            "HostCheckDelegate configured host=%s category=%s paths=%s "
            "warning_used_percent=%s critical_used_percent=%s",
            host,
            self._category,
            paths,
            warning,
            critical,
        )

    def get_alert_subscription_catalog(self):
        return build_alert_subscription_catalog(category=self._category)

    def evaluate_disk_state(self, disk_state):
        return self._tracker.evaluate(disk_state)

    def build_disk_alerts_from_host(self):
        hostname = socket.gethostname()
        state = collect_disk_state(self._paths, hostname)
        return self._tracker.evaluate(state)
