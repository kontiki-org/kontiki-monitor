import json
import subprocess
import time

import yaml
from behave import given, then, when
from pydantic import BaseModel

# Must match poll_interval_seconds in @fleet_state / @alert_silences / @disk configs.
FLEET_TEST_POLL_INTERVAL_SECONDS = 8
DISK_TEST_POLL_INTERVAL_SECONDS = 8

from tests.integration.utils import (
    start_host_check_for_scenario,
    start_kontiki_monitor_subprocess,
)
from tests.support.disk_fixture import set_mount_used_percent
from tests.support.harness import http_request

CATCHER = "alert-normalized-event-catcher"
SUT_NAME = "kontiki-monitor"
HOST_CHECK_NAME = "host-check-service"
PUBLISHER_NAME = "notification-publisher"
REGISTRY_MOCK = "ServiceRegistry"
SILENCE_RPC_METHODS = ("add_silence", "clear_silence")


def _normalize_actual_for_placeholders(expected, actual):
    if isinstance(expected, dict) and isinstance(actual, dict):
        normalized = {}
        for key, expected_value in expected.items():
            if key in actual:
                normalized[key] = _normalize_actual_for_placeholders(
                    expected_value, actual[key]
                )
        return normalized

    if isinstance(expected, list) and isinstance(actual, list):
        normalized = []
        for idx, expected_item in enumerate(expected):
            if idx < len(actual):
                normalized.append(
                    _normalize_actual_for_placeholders(expected_item, actual[idx])
                )
        return normalized

    return actual


def _payload_as_dict(payload):
    if isinstance(payload, dict):
        return payload
    if isinstance(payload, BaseModel):
        return payload.model_dump(mode="json")
    return payload


def _wait_for_http(base_url, timeout_seconds=15):
    deadline = time.time() + timeout_seconds
    last_error = None
    while time.time() < deadline:
        try:
            status, _body = http_request("GET", base_url.rstrip("/") + "/silences")
            if status == 200:
                return
        except Exception as exc:
            last_error = exc
        time.sleep(0.25)
    raise RuntimeError(
        "HTTP not ready at %s/silences (last_error=%s)" % (base_url, last_error)
    )


def _call_sut_rpc(context, method_name, payload):
    if method_name in SILENCE_RPC_METHODS and "service_name" in payload:
        name = payload["service_name"]
        rest = {key: value for key, value in payload.items() if key != "service_name"}
        return context.runner.call(SUT_NAME, method_name, name, **rest)
    return context.runner.call(SUT_NAME, method_name, **payload)


@given("the kontiki-monitor is running with the following configuration")
def step_service_running_with_configuration(context):
    config_text = context.text.strip()
    config = yaml.safe_load(config_text) or {}
    proc, config_path = start_kontiki_monitor_subprocess(config)
    context.kontiki_monitor_process = proc
    context.kontiki_monitor_config_path = config_path
    time.sleep(5)
    if proc.poll() is not None:
        stderr = (
            proc.stderr.read().decode(errors="replace") if proc.stderr else ""
        ) or "(empty)"
        raise RuntimeError(
            "kontiki-monitor subprocess exited before step. stderr:\n%s" % stderr
        )
    http_cfg = (config.get("kontiki") or {}).get("http") or {}
    port = http_cfg.get("port")
    address = http_cfg.get("address") or "127.0.0.1"
    if port is not None:
        _wait_for_http("http://%s:%s" % (address, port))


@given("the host-check-service is running with the following configuration")
def step_host_check_running_with_configuration(context):
    config = yaml.safe_load(context.text.strip()) or {}
    start_host_check_for_scenario(context, config)
    time.sleep(5)
    proc = context.host_check_process
    if proc is not None and proc.poll() is not None:
        stderr = (
            proc.stderr.read().decode(errors="replace") if proc.stderr else ""
        ) or "(empty)"
        raise RuntimeError(
            "host-check-service subprocess exited before step. stderr:\n%s" % stderr
        )
    fixture = context.host_check_disk_fixture
    if fixture is not None:
        name = fixture["container_name"]
        running = subprocess.check_output(
            ["docker", "inspect", "-f", "{{.State.Running}}", name],
            text=True,
        ).strip()
        if running != "true":
            logs = subprocess.check_output(["docker", "logs", name], text=True)
            raise RuntimeError(
                "host-check-service container not running. logs:\n%s" % logs
            )


@when("a disk usage poll observes the mounts filled as follows")
def step_disk_poll_observes_mounts_filled(context):
    fixture = context.host_check_disk_fixture
    assert fixture, "host-check disk fixture container is not running"
    host_by_container = fixture["host_by_container"]
    for row in context.table:
        container_path = row["path"]
        percent = row["percent"]
        host_dir = host_by_container.get(container_path)
        assert host_dir, "No host bind for mount %s" % container_path
        actual = set_mount_used_percent(host_dir, percent)
        assert actual == int(
            percent
        ), "Mount %s filled to %s%%, expected %s%%" % (container_path, actual, percent)
    context.manager.clean_events(CATCHER)
    time.sleep(DISK_TEST_POLL_INTERVAL_SECONDS + 5)


@when('a "{event_type}" event is published with payload')
def step_publish_registry_event_with_payload(context, event_type):
    payload = json.loads(context.text.strip()) if context.text else {}
    context.manager.clean_events(CATCHER)
    context.runner.call(
        PUBLISHER_NAME,
        "publish_event",
        event_type=event_type,
        payload=payload,
    )
    time.sleep(1)


@when("a fleet poll observes the Service Registry returning the following services")
def step_fleet_poll_observes_registry_services(context):
    services = json.loads(context.text.strip()) if context.text else {}
    context.manager.get_service(REGISTRY_MOCK).set_services(services)
    context.manager.clean_events(CATCHER)
    time.sleep(FLEET_TEST_POLL_INTERVAL_SECONDS + 5)


@then('an "{event_type}" event is published with payload')
def step_assert_event_with_payload(context, event_type):
    expected_payload = json.loads(context.text.strip()) if context.text else {}
    deadline = time.time() + 15
    last_events = []
    while time.time() < deadline:
        last_events = (
            context.manager.get_events(CATCHER, wait_for_events=1, timeout=2) or []
        )
        for event in last_events:
            if event.get("event_type") != event_type:
                continue
            actual_payload = _payload_as_dict(event.get("payload", {}))
            normalized = _normalize_actual_for_placeholders(
                expected_payload, actual_payload
            )
            if normalized == expected_payload:
                return
        time.sleep(0.25)

    assert False, "No matching %s event.\nExpected: %s\nRecent events: %s" % (
        event_type,
        expected_payload,
        last_events,
    )


@then('no "{event_type}" event is published')
def step_no_event_published(context, event_type):
    time.sleep(1)
    events = context.manager.get_events(CATCHER, wait_for_events=1, timeout=1) or []
    matching = [event for event in events if event.get("event_type") == event_type]
    assert not matching, "Unexpected %s events: %s" % (event_type, matching)


@then('no "{event_type}" event is published with event_type "{inner_event_type}"')
def step_no_alert_with_inner_event_type(context, event_type, inner_event_type):
    time.sleep(0.5)
    events = context.manager.get_events(CATCHER, wait_for_events=1, timeout=1) or []
    for event in events:
        if event.get("event_type") != event_type:
            continue
        payload = _payload_as_dict(event.get("payload", {}))
        if payload.get("event_type") == inner_event_type:
            assert False, "Unexpected alert with event_type=%s: %s" % (
                inner_event_type,
                payload,
            )


@then('no "{event_type}" event is published for service_name "{service_name}"')
def step_no_alert_for_service_name(context, event_type, service_name):
    time.sleep(0.5)
    events = context.manager.get_events(CATCHER, wait_for_events=1, timeout=1) or []
    for event in events:
        if event.get("event_type") != event_type:
            continue
        payload = _payload_as_dict(event.get("payload", {}))
        attributes = payload.get("attributes") or {}
        if attributes.get("service_name") == service_name:
            assert False, "Unexpected alert for service_name=%s: %s" % (
                service_name,
                payload,
            )


@when(
    "I call the RPC {method_name} on the kontiki-monitor with the following arguments"
)
def step_call_rpc(context, method_name):
    payload = json.loads(context.text.strip()) if context.text else {}
    if method_name in SILENCE_RPC_METHODS:
        context.manager.clean_events(CATCHER)
    context.last_rpc_error = None
    try:
        context.last_rpc_result = _call_sut_rpc(context, method_name, payload)
    except Exception as exc:
        context.last_rpc_result = None
        context.last_rpc_error = exc


@when(
    "I call the RPC {method_name} on the host-check-service with the following arguments"
)
def step_call_host_check_rpc(context, method_name):
    payload = json.loads(context.text.strip()) if context.text else {}
    context.last_rpc_error = None
    try:
        context.last_rpc_result = context.runner.call(
            HOST_CHECK_NAME, method_name, **payload
        )
    except Exception as exc:
        context.last_rpc_result = None
        context.last_rpc_error = exc


@then("the kontiki-monitor RPC call succeeds")
def step_rpc_succeeds(context):
    if context.last_rpc_error is not None:
        raise AssertionError(
            "Expected RPC success, got error: %s" % context.last_rpc_error
        )


@then("the host-check-service RPC call succeeds")
def step_host_check_rpc_succeeds(context):
    if context.last_rpc_error is not None:
        raise AssertionError(
            "Expected RPC success, got error: %s" % context.last_rpc_error
        )


@then("the kontiki-monitor RPC response is")
def step_rpc_response_is(context):
    expected = json.loads(context.text.strip()) if context.text else {}
    actual = _payload_as_dict(context.last_rpc_result)
    assert actual == expected, "Expected %s, got %s" % (expected, actual)


@then("the host-check-service RPC response is")
def step_host_check_rpc_response_is(context):
    expected = json.loads(context.text.strip()) if context.text else {}
    actual = _payload_as_dict(context.last_rpc_result)
    assert actual == expected, "Expected %s, got %s" % (expected, actual)


@then("the kontiki-monitor RPC response includes the event types")
def step_rpc_response_includes_event_types(context):
    expected_event_types = json.loads(context.text.strip()) if context.text else []
    actual = _payload_as_dict(context.last_rpc_result)
    categories = actual.get("categories") or []
    found = []
    for category in categories:
        found.extend(category.get("event_types") or [])
    by_type = {item.get("event_type"): item for item in found}
    for expected in expected_event_types:
        event_type = expected.get("event_type")
        assert event_type in by_type, "Missing event_type %s in %s" % (
            event_type,
            list(by_type),
        )
        assert (
            by_type[event_type] == expected
        ), "Event type mismatch for %s: %s vs %s" % (
            event_type,
            by_type[event_type],
            expected,
        )


@when(
    "I call {method} on the kontiki-monitor on {url} with the following request"
)
def step_call_http(context, method, url):
    payload = json.loads(context.text.strip()) if context.text else {}
    headers = payload.get("headers")
    body = payload.get("payload")
    if method.upper() in ("POST", "DELETE") and "/silences" in url:
        context.manager.clean_events(CATCHER)
    status, resp_body = http_request(method, url, payload=body, headers=headers)
    context.last_http_status = status
    context.last_http_body = resp_body


@then("the kontiki-monitor HTTP call succeeds with status {status:d}")
def step_http_succeeds(context, status):
    assert context.last_http_status == status, "Expected HTTP %s, got %s body=%s" % (
        status,
        context.last_http_status,
        context.last_http_body,
    )


@then("the kontiki-monitor HTTP response is")
def step_http_response_is(context):
    expected = json.loads(context.text.strip()) if context.text else {}
    actual = _payload_as_dict(context.last_http_body)
    assert actual == expected, "Expected %s, got %s" % (expected, actual)
