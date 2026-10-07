from kontiki.messaging import Messenger, on_event, rpc
from kontiki.testing import MockService
from kontiki.web import http

SENTINEL_MOCK = "sentinel-mock"
SENTINEL_MOCK_PORT = 18282
# Same URL as tests/integration/sentinel-heartbeat.feature.
SENTINEL_HEARTBEAT_PATH = "/watchdogs/prod/heartbeat"
SENTINEL_REGISTRY_FAIL = object()
SENTINEL_UNREACHABLE = "unreachable"


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
    """Sole ServiceRegistry on the bus when tests use RabbitMQ only (make run-amqp)."""

    name = "ServiceRegistry"

    @rpc
    async def get_services(self, status=None):
        _ = status
        self.remote_call_manager.store_call_args()
        value = self.remote_call_manager.get_return_value()
        if value is SENTINEL_REGISTRY_FAIL:
            raise RuntimeError("scripted registry failure")
        return value


class SentinelHttpMock(MockService):
    name = SENTINEL_MOCK

    @http(SENTINEL_HEARTBEAT_PATH, "POST")
    async def heartbeat(self, request):
        body = await request.read()
        self.http_manager.store_request(
            {
                "url": str(request.url),
                "headers": {str(key): value for key, value in request.headers.items()},
                "body": body.decode("utf-8"),
            }
        )
        response = self.http_manager.get_response()
        if response == SENTINEL_UNREACHABLE:
            request.transport.close()
            raise ConnectionResetError("sentinel unreachable")
        return response
