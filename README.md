# kontiki-monitor

Judges Kontiki Registry state (fleet expectations + registry bus events) and publishes
`alert.normalized` for Boomerang.

Boomerang does **not** depend on this repo. This repo owns the **embedded ops stack**
that pulls Boomerang images from a sibling checkout.

## Dependencies

- `kontiki>=1.2.0`
- `boomerang-contracts` (path: `../boomerang/packages/boomerang-contracts` until PyPI)
- Sibling `../boomerang` for Docker builds of Boomerang services

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

Start a bus **without** the real Registry (Behave owns `ServiceRegistry`):

```bash
# from Boomerang (bus only)
make run-dev-platform-no-registry

# from this repo
make integration-test
```

## Docker (monitor image alone)

Build from the parent of both repos:

```bash
docker build -f kontiki-monitor/Dockerfile -t kontiki-monitor .
```
