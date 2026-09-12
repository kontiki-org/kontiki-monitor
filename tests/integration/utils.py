from tests.support.disk_fixture import start_host_check_disk_container
from tests.support.harness import start_kontiki_subprocess


def start_kontiki_monitor_subprocess(config, amqp_disconnected=False):
    return start_kontiki_subprocess(
        "kontiki_monitor.service.KontikiMonitorService",
        config,
        amqp_disconnected=amqp_disconnected,
    )


def start_host_check_subprocess(config, amqp_disconnected=False):
    return start_kontiki_subprocess(
        "kontiki_host_check.service.HostCheckService",
        config,
        amqp_disconnected=amqp_disconnected,
    )


def start_host_check_for_scenario(context, config):
    amqp_disconnected = bool(getattr(context, "amqp_disconnected", False))
    if "disk" in context.tags:
        fixture = start_host_check_disk_container(
            config, amqp_disconnected=amqp_disconnected
        )
        context.host_check_disk_fixture = fixture
        context.host_check_process = None
        context.host_check_config_path = None
        return
    proc, config_path = start_host_check_subprocess(
        config, amqp_disconnected=amqp_disconnected
    )
    context.host_check_process = proc
    context.host_check_config_path = config_path
    context.host_check_disk_fixture = None
