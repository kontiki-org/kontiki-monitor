import subprocess
import time

from kontiki.testing import MockServiceManager, MockServiceRunner

from tests.support.harness import safe_unlink
from tests.support.mocks import (
    AlertNormalizedEventCatcher,
    NotificationPublisherMock,
    ServiceRegistryMock,
)


def before_all(context):
    time.sleep(1)
    context.kontiki_monitor_process = None
    context.kontiki_monitor_config_path = None
    context.last_rpc_result = None
    context.last_rpc_error = None
    context.last_http_status = None
    context.last_http_body = None

    default_config = {"kontiki": {"amqp": {"url": "amqp://guest:guest@localhost/"}}}
    context.manager = MockServiceManager(log_file="/tmp/kontiki-monitor-integration.log")
    context.manager.add(NotificationPublisherMock, default_config)
    context.manager.add(AlertNormalizedEventCatcher, default_config)
    context.manager.add(ServiceRegistryMock, default_config)
    context.runner = MockServiceRunner(context.manager)
    context.runner.start()
    context.runner.ready_event.wait(timeout=10)


def before_scenario(context, scenario):
    _ = scenario
    context.last_rpc_result = None
    context.last_rpc_error = None
    context.last_http_status = None
    context.last_http_body = None
    context.manager.clean_events("alert-normalized-event-catcher")
    context.manager.get_service("ServiceRegistry").set_services({})


def after_scenario(context, scenario):
    _ = scenario
    if context.kontiki_monitor_process is not None:
        context.kontiki_monitor_process.terminate()
        try:
            context.kontiki_monitor_process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            context.kontiki_monitor_process.kill()
            context.kontiki_monitor_process.wait(timeout=5)
        context.kontiki_monitor_process = None

    safe_unlink(context.kontiki_monitor_config_path)
    context.kontiki_monitor_config_path = None
    context.manager.clean_events("alert-normalized-event-catcher")


def after_all(context):
    context.runner.stop()
