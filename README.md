# kontiki-monitor

> **Part of the Kontiki suite** — a compact open-source stack for startups and
> small teams that need ops without the heavy stack.
>
> Full suite overview → https://kontiki-org.github.io/


Kontiki-monitor watches a Kontiki platform and raises alerts.
[Boomerang](https://github.com/kontiki-org/boomerang) delivers them (email, Telegram, …).

## Services

| Service | Alerts | Image |
|---|---|---|
| [kontiki-monitor](src/kontiki_monitor/README.md) | A service missing or short of active instances. An instance that registers, leaves, or changes state. The first sight of an exception, recovered after a quiet period. Three failed sentinel heartbeats. | `ghcr.io/kontiki-org/kontiki-monitor:1.0.0` |
| [host-check-service](src/kontiki_host_check/README.md) | Disk usage at warning, then critical, recovered when usage drops. A path that cannot be measured. | `ghcr.io/kontiki-org/host-check-service:1.0.0` |

Those images run the two daemons. `pip install kontiki-monitor` installs the same commands.

Boomerang runs from its own images. [`boomerang-contracts`](https://pypi.org/project/boomerang-contracts/) is a `pip install` for code that emits alerts.

Each service README lists its keys. A Registry and an AMQP broker sit beside the processes, as for any other Kontiki service.

## Try it

Docker Compose runs a demo app, the monitor, Boomerang, and a local mailbox (MailHog on `http://127.0.0.1:8025`). Telegram is optional: [bot token and chat id](docs/DEPLOYMENT_EMBEDDED.md#telegram).

```bash
make stack-up
make demo-app-degrade
```

<p align="center">
  <img src="./assets/telegram-demo-app-degraded.png" alt="Telegram notification when demo-app-service goes degraded" width="420">
</p>

```bash
make demo-app-recover
make stack-down
```

What the stack runs, and how to point it at your own chat: [docs/DEPLOYMENT_EMBEDDED.md](docs/DEPLOYMENT_EMBEDDED.md).
