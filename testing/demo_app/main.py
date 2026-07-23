from kontiki.runner import cli

from demo_app.service import DemoAppService


def run():
    cli.run(
        DemoAppService,
        "Demo Kontiki app for Registry alerting (embedded profile).",
        version="0.1.0",
        disable_service_registration=False,
    )


if __name__ == "__main__":
    run()
