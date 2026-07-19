from tests.support.harness import start_kontiki_subprocess


def start_kontiki_monitor_subprocess(config):
    return start_kontiki_subprocess(
        "kontiki_monitor.service.KontikiMonitorService",
        config,
    )
