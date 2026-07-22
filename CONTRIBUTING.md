# Contributing to kontiki-monitor

This repository follows the same contribution spirit as [Kontiki](https://github.com/kontiki-org/kontiki). For general expectations (maintainer-led model, opening an issue for non-trivial work), see [Contributing to Kontiki](https://github.com/kontiki-org/kontiki/blob/main/CONTRIBUTING.md).

kontiki-monitor is a small Kontiki ops suite: **kontiki-monitor** judges Registry fleet state and bus events; **host-check-service** watches local disk occupation. Both publish `alert.normalized` for consumption by an alerting stack such as Boomerang.

For changes in **this repo**, please:

- Open an issue first for non-trivial work and describe the problem, the intended scope, and which service it affects (`kontiki-monitor` and/or `host-check-service`).
- Prefer **small, focused** pull requests with Behave coverage when behaviour changes.
- Match existing style in the files you touch.

## Local checks

```bash
poetry install
make check
make run-amqp
make integration-test
```

`make check` runs `isort` / `black` on `src/`, then `flake8`.

CI on GitHub runs **lint only** (Python 3.11–3.13). Run Behave locally before
opening a non-trivial PR — suites are too long for the default pipeline.

Tagged suites (examples):

```bash
make integration-test-tag TAG=host_check
make integration-test-tag TAG=kontiki_monitor
```

`make run-amqp` starts RabbitMQ only. Behave owns a `ServiceRegistry` mock — do not start a real Registry alongside these tests.

Disk scenarios (`@disk`) build a local Docker image and use privileged tmpfs fixtures; Docker must be available.

## Embedded stack (optional)

Full Registry + monitor + notifiers (for manual ops demos):

```bash
make stack-up
make stack-down
```

By contributing, you agree your contribution is licensed under the same terms as this project ([Apache License 2.0](LICENSE)).
