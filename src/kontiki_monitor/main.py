from kontiki.runner import cli

from kontiki_monitor import __version__
from kontiki_monitor.service import KontikiMonitorService


def run() -> None:
    cli.run(
        KontikiMonitorService,
        "Kontiki monitor (Registry fleet + events -> alert.normalized).",
        version=__version__,
        disable_service_registration=False,
    )


if __name__ == "__main__":
    run()
