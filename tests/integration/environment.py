import os
import shutil
import subprocess
import time

from aiohttp import web
from kontiki.testing import MockServiceManager, MockServiceRunner

from tests.support.disk_fixture import stop_host_check_disk_container
from tests.support.harness import repo_root, safe_unlink
from tests.support.mocks import (
    SENTINEL_MOCK,
    SENTINEL_MOCK_PORT,
    SENTINEL_REGISTRY_FAIL,
    SENTINEL_UNREACHABLE,
    AlertNormalizedEventCatcher,
    NotificationPublisherMock,
    SentinelHttpMock,
    ServiceRegistryMock,
)

# One tag per scenario. Each entry is the full sequence consumed by that scenario.
_SENTINEL_SCRIPTS = {
    "sentinel_204": {
        "registry": [{}],
        "http": [204],
    },
    "sentinel_registry_fail_then_204": {
        "registry": [SENTINEL_REGISTRY_FAIL, {}],
        "http": [204],
    },
    "sentinel_third_failure_then_recover": {
        "registry": [{}, {}, {}, {}, {}],
        "http": [SENTINEL_UNREACHABLE, 503, SENTINEL_UNREACHABLE, 503, 204],
    },
    "sentinel_success_clears_streak": {
        "registry": [{}, {}, {}, {}],
        "http": [SENTINEL_UNREACHABLE, SENTINEL_UNREACHABLE, 204, SENTINEL_UNREACHABLE],
    },
}


def _stop_process(proc):
    if proc is None:
        return
    proc.terminate()
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait(timeout=5)


def before_all(context):
    time.sleep(1)
    context.kontiki_monitor_process = None
    context.kontiki_monitor_config_path = None
    context.kontiki_monitor_config = None
    context.host_check_process = None
    context.host_check_config_path = None
    context.host_check_disk_fixture = None
    context.scenario_dir = None
    context.last_rpc_result = None
    context.last_rpc_error = None
    context.last_http_status = None
    context.last_http_body = None

    default_config = {"kontiki": {"amqp": {"url": "amqp://guest:guest@localhost/"}}}
    sentinel_config = {
        "kontiki": {
            "amqp": {"url": "amqp://guest:guest@localhost/"},
            "http": {"address": "127.0.0.1", "port": SENTINEL_MOCK_PORT},
        }
    }
    context.manager = MockServiceManager(
        log_file="/tmp/kontiki-monitor-integration.log"
    )
    context.manager.add(NotificationPublisherMock, default_config)
    context.manager.add(AlertNormalizedEventCatcher, default_config)
    context.manager.add(ServiceRegistryMock, default_config)
    context.manager.add(SentinelHttpMock, sentinel_config)
    context.runner = MockServiceRunner(context.manager)
    context.runner.start()
    context.runner.ready_event.wait(timeout=10)


def _queue_sentinel_script(context, tags):
    script = None
    for name, value in _SENTINEL_SCRIPTS.items():
        if name in tags:
            script = value
            break
    if script is None:
        return
    for item in script["registry"]:
        context.manager.add_remote_return_value("ServiceRegistry", item)
    for item in script["http"]:
        if item == SENTINEL_UNREACHABLE:
            response = SENTINEL_UNREACHABLE
        else:
            response = web.Response(status=item)
        context.manager.add_http_response(SENTINEL_MOCK, response)


def before_scenario(context, scenario):
    context.amqp_disconnected = "amqp_disconnected" in scenario.effective_tags
    context.kontiki_monitor_config = None
    context.scenario_dir = None
    context.last_rpc_result = None
    context.last_rpc_error = None
    context.last_http_status = None
    context.last_http_body = None
    # Default silences_path is cwd/silences.json; clear leftovers between scenarios.
    safe_unlink(os.path.join(str(repo_root()), "silences.json"))
    context.manager.clean_events("alert-normalized-event-catcher")
    context.manager.clean_remote_calls("ServiceRegistry")
    context.manager.clean_http_requests(SENTINEL_MOCK)
    _queue_sentinel_script(context, scenario.effective_tags)
    context.sentinel_rpc_index = 0
    context.sentinel_http_index = 0


def after_scenario(context, scenario):
    _ = scenario
    _stop_process(context.kontiki_monitor_process)
    context.kontiki_monitor_process = None
    safe_unlink(context.kontiki_monitor_config_path)
    context.kontiki_monitor_config_path = None
    context.kontiki_monitor_config = None

    _stop_process(context.host_check_process)
    context.host_check_process = None
    safe_unlink(context.host_check_config_path)
    context.host_check_config_path = None

    stop_host_check_disk_container(context.host_check_disk_fixture)
    context.host_check_disk_fixture = None

    if context.scenario_dir:
        shutil.rmtree(context.scenario_dir, ignore_errors=True)
        context.scenario_dir = None

    context.manager.clean_events("alert-normalized-event-catcher")
    context.manager.clean_remote_calls("ServiceRegistry")
    context.manager.clean_http_requests(SENTINEL_MOCK)


def after_all(context):
    context.runner.stop()
