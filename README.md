# kontiki-monitor

Judges Kontiki Registry state (fleet expectations + registry bus events) and publishes
`alert.normalized` for Boomerang.

Boomerang does **not** depend on this repo. This repo owns the **embedded ops stack**
and builds Boomerang service images from PyPI (`kontiki-boomerang`).

## Dependencies

- `kontiki>=1.3.0`
- `boomerang-contracts>=0.1.0,<0.2.0` (PyPI)
- Embedded stack images: `kontiki-boomerang>=0.1.0,<0.2.0` and `kontiki>=1.3.0` (PyPI, via Dockerfiles)

## Local install

```bash
poetry install
```

## Embedded stack

```bash
make stack-up      # Registry + kontiki-monitor + Boomerang + MailHog
make stack-down
make demo-app-degrade   # then check MailHog :8025
```

Silences HTTP: `http://127.0.0.1:8091/silences`  
Fleet config: `config/default.yaml` + `config/embedded.yaml`  
Boomerang presets: `stack/subscription.yaml`, `stack/email_notifier.yaml`, …

## Integration tests

Behave owns a `ServiceRegistry` mock on the bus — start **RabbitMQ only** (no real Registry):

```bash
make run-amqp
make integration-test
```

Do not use Boomerang `make run-dev-platform` for these tests: it starts a real Registry and conflicts with the mock.

## Docker (monitor image alone)

```bash
docker build -t kontiki-monitor .
```
