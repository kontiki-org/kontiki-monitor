from kontiki.messaging import Messenger, on_event, rpc
from kontiki.testing import MockService


class NotificationPublisherMock(MockService):
    name = "notification-publisher"
    messenger = Messenger()

    @rpc
    async def publish_notification_requested(self, payload):
        channel = "email"
        if isinstance(payload, dict):
            channel = (payload.get("channel") or "email").strip() or "email"
        await self.messenger.publish(
            f"{channel}.alerting.notification.requested", payload
        )

    @rpc
    async def publish_event(self, event_type, payload):
        await self.messenger.publish(event_type, payload)


class AlertNormalizedEventCatcher(MockService):
    name = "alert-normalized-event-catcher"

    @on_event("alert.normalized")
    async def on_alert_normalized(self, payload):
        self.event_manager.store_event(
            {"event_type": "alert.normalized", "payload": payload}
        )


class ServiceRegistryMock(MockService):
    """Sole ServiceRegistry on the bus when using run-dev-platform-no-registry."""

    name = "ServiceRegistry"

    def __init__(self):
        self.services_snapshot = {}

    def set_services(self, services):
        self.services_snapshot = services if services is not None else {}

    @rpc
    async def get_services(self, status=None):
        _ = status
        return self.service_instance.services_snapshot
