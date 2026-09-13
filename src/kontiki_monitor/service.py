import logging

from aiohttp import web
from boomerang_contracts.alert.normalized import ALERT_NORMALIZED_EVENT
from kontiki.messaging import AmqpDisconnectedError, Messenger, on_event, rpc, rpc_error
from kontiki.task.task import task
from kontiki.web.web import http

from kontiki_monitor.alert_mapping import (
    REGISTRY_EVENT_EXCEPTION_RECORDED,
    REGISTRY_EVENT_INSTANCE_DEREGISTERED,
    REGISTRY_EVENT_INSTANCE_REGISTERED,
    REGISTRY_EVENT_INSTANCE_STATUS_CHANGED,
)
from kontiki_monitor.delegate import KontikiMonitorDelegate
from kontiki_monitor.fleet_state import FLEET_POLL_INTERVAL_CONFIG_KEY
from kontiki_monitor.names import KONTIKI_MONITOR_SERVICE_NAME


class KontikiMonitorService:
    name = KONTIKI_MONITOR_SERVICE_NAME
    delegate = KontikiMonitorDelegate()
    messenger = Messenger()

    @rpc
    async def get_alert_subscription_catalog(self):
        return self.delegate.get_alert_subscription_catalog()

    @rpc
    async def add_silence(self, service_name):
        try:
            return self.delegate.add_silence(service_name)
        except ValueError as exc:
            return rpc_error("INVALID_SERVICE_NAME", str(exc))

    @rpc
    async def clear_silence(self, service_name):
        try:
            return self.delegate.clear_silence(service_name)
        except ValueError as exc:
            return rpc_error("INVALID_SERVICE_NAME", str(exc))

    @rpc
    async def list_silences(self):
        return self.delegate.list_silences()

    @rpc
    async def list_open_alerts(self):
        return self.delegate.list_open_alerts()

    @http("/silences", "GET")
    async def http_list_silences(self, request):
        _ = request
        return self.delegate.list_silences()

    @http("/silences", "POST")
    async def http_add_silence(self, request):
        try:
            body = await request.json()
        except Exception as err:
            raise web.HTTPBadRequest(reason="Invalid JSON body") from err
        if not isinstance(body, dict):
            raise web.HTTPBadRequest(reason="JSON object required")
        try:
            return self.delegate.add_silence(body.get("service_name"))
        except ValueError as err:
            raise web.HTTPBadRequest(reason=str(err)) from err

    @http("/silences/{service_name}", "DELETE")
    async def http_clear_silence(self, request, service_name):
        _ = request
        try:
            return self.delegate.clear_silence(service_name)
        except ValueError as err:
            raise web.HTTPBadRequest(reason=str(err)) from err

    @on_event(REGISTRY_EVENT_INSTANCE_REGISTERED)
    async def on_instance_registered(self, payload):
        await self._publish_normalized_alert(
            REGISTRY_EVENT_INSTANCE_REGISTERED, payload
        )

    @on_event(REGISTRY_EVENT_INSTANCE_DEREGISTERED)
    async def on_instance_deregistered(self, payload):
        await self._publish_normalized_alert(
            REGISTRY_EVENT_INSTANCE_DEREGISTERED, payload
        )

    @on_event(REGISTRY_EVENT_INSTANCE_STATUS_CHANGED)
    async def on_instance_status_changed(self, payload):
        await self._publish_normalized_alert(
            REGISTRY_EVENT_INSTANCE_STATUS_CHANGED, payload
        )

    @on_event(REGISTRY_EVENT_EXCEPTION_RECORDED)
    async def on_exception_recorded(self, payload):
        alerts = self.delegate.observe_exception_recorded(payload)
        for alert in alerts:
            logging.info(
                "Publishing exception alert.normalized alert_id=%s resolution=%s",
                alert.alert_id,
                alert.attributes.get("resolution"),
            )
            await self._publish_alert_normalized(alert)

    @task(interval=FLEET_POLL_INTERVAL_CONFIG_KEY, immediate=False)
    async def poll_fleet_state(self):
        alerts = await self.delegate.build_fleet_alerts()
        for alert in alerts:
            logging.info(
                "Publishing fleet alert.normalized event_type=%s alert_id=%s "
                "resolution=%s",
                alert.event_type,
                alert.alert_id,
                alert.attributes.get("resolution"),
            )
            await self._publish_alert_normalized(alert)

    @task(interval=FLEET_POLL_INTERVAL_CONFIG_KEY, immediate=False)
    async def poll_exception_fingerprints(self):
        alerts = self.delegate.sweep_exception_fingerprints()
        for alert in alerts:
            logging.info(
                "Publishing exception recover alert.normalized alert_id=%s",
                alert.alert_id,
            )
            await self._publish_alert_normalized(alert)

    async def _publish_normalized_alert(self, registry_event_type, payload):
        alert = self.delegate.build_normalized_alert(registry_event_type, payload)
        if alert is None:
            return
        logging.info(
            "Publishing alert.normalized for registry event %s alert_id=%s",
            registry_event_type,
            alert.alert_id,
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
