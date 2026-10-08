from kontiki.runner import cli

from kontiki_host_check import __version__
from kontiki_host_check.service import HostCheckService


def run():
    cli.run(
        HostCheckService,
        "Host check (local disk occupation -> alert.normalized).",
        version=__version__,
        disable_service_registration=False,
    )


if __name__ == "__main__":
    run()
