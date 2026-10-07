# Deployment — embedded stack (kontiki-monitor)

Headless Kontiki alerting: Registry → **kontiki-monitor** → `alert.normalized` → Boomerang (subscriptions / email / telegram).

Owned by the **kontiki-monitor** repo. Boomerang has no knowledge of this stack.

## Prerequisites

- Docker Compose
- Network access to PyPI (`kontiki`, `kontiki-boomerang`, `boomerang-contracts`)
- Optional Telegram: [bot token and chat id](#telegram)

No sibling `../boomerang` checkout is required.

## Start / stop

From this repo:

```bash
make stack-up
make stack-down
```

Images:

| Image | Source |
|---|---|
| `kontiki-monitor:local` | this repo `Dockerfile` (`boomerang-contracts` from PyPI) |
| `kontiki-monitor-boomerang:local` | `Dockerfile.boomerang` (`kontiki-boomerang>=2.1.0` from PyPI) |
| `kontiki-monitor-registry:local` | `Dockerfile.kontiki-registry` (`kontiki>=1.4.0` from PyPI) |

Liveness probes use registry `GET /live/<service_name>` (Kontiki 1.3+), including `GET /live/ServiceRegistry` for the registry itself.

## What runs

| Service | Role |
|---|---|
| rabbitmq | bus |
| kontiki-registry | Kontiki registry |
| kontiki-monitor | Registry events + fleet → `alert.normalized` (HTTP silences `:8091`) |
| subscription-service | YAML subscriptions (Boomerang) |
| alert-engine-service | notification dispatch (Boomerang) |
| email-notifier-service | email (MailHog locally) |
| telegram-notifier-service | telegram |
| demo-app-service | demo Kontiki app (`make demo-app-degrade`) |
| mailhog | SMTP demo (`:8025`) |

## Configure

- Fleet / poll: `config/default.yaml`, `config/embedded.yaml`
- Subscriptions / endpoints (YAML-only): `stack/subscription.yaml`, `stack/email_notifier.yaml`, `stack/telegram_notifier.yaml`

## Demo

```bash
make stack-up
make demo-app-degrade
# MailHog UI → http://127.0.0.1:8025
make demo-app-recover
```

`make demo-app-*` runs `python -m boomerang.testing.demo_app.cli` inside `kontiki-monitor-boomerang:local` with `--network host` (RPC over `localhost:5672`).

## Telegram

Email via MailHog works without this. Telegram needs a bot token and a chat id.

**Bot token**

1. Open Telegram and talk to [@BotFather](https://t.me/BotFather).
2. Send `/newbot` and follow the prompts (display name + username ending in `bot`).
3. BotFather replies with a token like `123456:ABC-DEF...`.
4. Copy the example and set the token:

```bash
cp stack/telegram_notifier_bot_token.yaml.example \
   stack/telegram_notifier_bot_token.yaml
```

```yaml
app:
  telegram:
    bot_token: "YOUR_BOT_TOKEN"
```

Keep that file local (it is gitignored).

**Chat id**

1. Start a chat with the bot (press Start), or add it to a group.
2. Send any message in that chat.
3. Open `https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates` in a browser.
4. In the JSON, `"chat":{"id": ...}` is the `chat_id` (often negative for a group).
5. Set it in `stack/telegram_notifier.yaml` as a string:

```yaml
app:
  endpoints:
    ops_alerts:
      chat_id: "YOUR_CHAT_ID"
```

The sandbox subscription already routes a `degraded` state change to `telegram.ops_alerts` and `email.oncall`.
