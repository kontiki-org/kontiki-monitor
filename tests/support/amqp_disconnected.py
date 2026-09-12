"""Harness: Messenger.publish raises AmqpDisconnectedError (SUT process only)."""


def patch_messenger_publish_disconnected():
    from kontiki.messaging import AmqpDisconnectedError
    from kontiki.messaging.publisher.messenger import Messenger

    async def _disconnected_publish(self, *args, **kwargs):
        raise AmqpDisconnectedError()

    Messenger.publish = _disconnected_publish


HOST_CHECK_DISCONNECTED_BOOTSTRAP = """
import sys
sys.argv = ["host-check-service", "--config", "/config/service.yaml"]
from kontiki.messaging import AmqpDisconnectedError
from kontiki.messaging.publisher.messenger import Messenger

async def _disconnected_publish(self, *args, **kwargs):
    raise AmqpDisconnectedError()

Messenger.publish = _disconnected_publish
from kontiki_host_check.main import run
run()
"""
