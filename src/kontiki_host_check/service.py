import logging

from boomerang_contracts.alert.normalized import ALERT_NORMALIZED_EVENT
from kontiki.messaging import AmqpDisconnectedError, Messenger, rpc
from kontiki.task.task import task

from kontiki_host_check.delegate import HostCheckDelegate
from kontiki_host_check.disk_state import DISK_POLL_INTERVAL_CONFIG_KEY
from kontiki_host_check.names import HOST_CHECK_SERVICE_NAME


class HostCheckService:
    name = HOST_CHECK_SERVICE_NAME
    delegate = HostCheckDelegate()
    messenger = Messenger()

    @rpc
    async def get_alert_subscription_catalog(self):
        return self.delegate.get_alert_subscription_catalog()

    @rpc
    async def list_open_alerts(self):
        return self.delegate.list_open_alerts()

    @task(interval=DISK_POLL_INTERVAL_CONFIG_KEY, immediate=True)
    async def poll_disk_usage(self):
        alerts = self.delegate.build_disk_alerts_from_host()
        for alert in alerts:
            logging.info(
                "Publishing disk alert.normalized event_type=%s alert_id=%s "
                "resolution=%s severity=%s",
                alert.event_type,
                alert.alert_id,
                alert.attributes.get("resolution"),
                alert.severity,
            )
            await self._publish_alert_normalized(alert)

    async def _publish_alert_normalized(self, alert):
        try:
            await self.messenger.publish(ALERT_NORMALIZED_EVENT, alert)
        except AmqpDisconnectedError:
            logging.warning(
                "Skipping alert.normalized publish while Messenger is disconnected "
                "alert_id=%s event_type=%s",
                alert.alert_id,
                alert.event_type,
            )
