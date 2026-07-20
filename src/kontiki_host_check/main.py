from kontiki.runner import cli

from kontiki_host_check.service import HostCheckService


def run():
    cli.run(
        HostCheckService,
        "Host check (local disk occupation -> alert.normalized).",
        version="0.1.0",
        disable_service_registration=False,
    )


if __name__ == "__main__":
    run()
