"""Minimal Kontiki app used to exercise Registry alerts in the embedded stack."""

from kontiki.messaging import Messenger, rpc
from kontiki.registry import degraded_on

from demo_app.delegate import DemoAppDelegate

DEMO_APP_SERVICE_NAME = "demo-app-service"


class DemoAppService:
    name = DEMO_APP_SERVICE_NAME
    delegate = DemoAppDelegate()
    messenger = Messenger()

    @rpc
    async def set_degraded(self, degraded=True):
        return self.delegate.set_degraded(degraded)

    @rpc
    async def get_degraded(self):
        return self.delegate.get_degraded()

    @degraded_on
    def is_degraded(self):
        return self.delegate.is_degraded()

    @rpc
    async def raise_exception(self):
        raise Exception("Uncaught exception in demo-app-service")
