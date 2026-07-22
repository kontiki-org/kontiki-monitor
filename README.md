# kontiki-monitor

> **Part of the Kontiki suite** — a compact open-source stack for startups and
> small teams that need ops without the heavy stack.
>
> - Build with [Kontiki](https://github.com/kontiki-org/kontiki)
> - See with [kontiki-tui](https://github.com/kontiki-org/kontiki-tui)
> - Get alerted with [kontiki-monitor](https://github.com/kontiki-org/kontiki-monitor)
>
> Full ops demo → [Quickstart](#quickstart--demo-app--telegram) below.


Kontiki-monitor is a small, practical ops suite for Kontiki platforms — complete enough to run, simple enough to own.


[Boomerang](https://github.com/kontiki-org/boomerang) is the Kontiki alerting engine:
YAML subscriptions match normalized alerts and route them to notifiers (email, Telegram, …).
This repository ships two Kontiki services that plug into it: they judge Registry fleet
state, registry lifecycle events (including recorded exceptions), and local disk
occupation, then publish `alert.normalized` for those subscriptions and notifiers.

| Service | CLI | Config | Role |
|---|---|---|---|
| `kontiki-monitor` | `kontiki-monitor` | `kontiki-monitor:` in `config/default.yaml` (+ `config/embedded.yaml`) | Fleet expectations, Registry state changes, and recorded exceptions → alerts |
| `host-check-service` | `host-check-service` | `host-check:` in `config/host-check.yaml` | Local disk occupation (warning/critical %, paths); one instance per host |

---

## Quickstart — demo-app → Telegram

The quickstart runs
  - a **demo Kontiki service** (`demo-app`) as the business workload under watch
  - the **ops stack** that watches it: Registry, **kontiki-monitor**, Boomerang
(subscription / alert-engine / notifiers), and MailHog (local SMTP sink so you can inspect
email alerts without a real mailbox). Degrade the demo app; ops get a Telegram (and email)
alert.


**1. Telegram bot token** (optional but needed for Telegram) — see
[NB — Telegram bot token and chat id](#nb--telegram-bot-token-and-chat-id):

```bash
cp stack/telegram_notifier_bot_token.yaml.example \
   stack/telegram_notifier_bot_token.yaml
# set app.telegram.bot_token from BotFather
```

**2. Start the stack:**

```bash
make stack-up
```

**Optional — observe with kontiki-tui** (dev dep via `poetry install`):

```bash
make tui
```

**3. Target a chat** — operator config already wired for registry `degraded` state changes:

```yaml
# stack/subscription.yaml (excerpt)
app:
  subscriptions:
    platform-ops:          # owner_id → recipient_id at dispatch
      demo-app-degraded:   # rule_name (subscription id under that owner)
        status: active
        subscription:
          rule:
            category: kontiki.registry
            event_type: instance_state_changed
            criteria:
              all_of:
                - key: new_state
                  operator: eq
                  value: degraded
          endpoints:
            - telegram.ops_alerts   # <channel>.<endpoint_id> → telegram_notifier endpoints.ops_alerts
            - email.oncall         # <channel>.<endpoint_id> → email_notifier endpoints.oncall
```

```yaml
# stack/telegram_notifier.yaml (excerpt)
app:
  endpoints:
    ops_alerts:
      chat_id: "YOUR_CHAT_ID"
```

Fleet expectation for the demo (monitor opens/recovers `insufficient` / `missing` as well):

```yaml
# config/embedded.yaml (excerpt)
kontiki-monitor:
  expected_services:
    demo-app-service:
      min_active: 1
```

**4. Trigger an alert:**

```bash
make demo-app-degrade
# wait a few seconds (demo heartbeat is 5s)
```

Telegram looks like this:

<p align="center">
  <img src="./assets/telegram-demo-app-degraded.png" alt="Telegram notification when demo-app-service goes degraded" width="420">
</p>

Email lands in MailHog: `http://127.0.0.1:8025`.

Recover and stop:

```bash
make demo-app-recover
make stack-down
```

---

## Install

```bash
pip install kontiki-monitor
```

Entry points: `kontiki-monitor` and `host-check-service` (pass one or more `--config`
YAML files). The [Quickstart](#quickstart--demo-app--telegram) above uses Docker Compose
instead of a local pip install.

([package on PyPI](https://pypi.org/project/kontiki-monitor/))

## Integration tests

```bash
make run-amqp
make integration-test
```

---

## NB — Telegram bot token and chat id

Needed only if you want Telegram in the quickstart (email via MailHog works without it).

**Bot token**

1. Open Telegram and talk to [@BotFather](https://t.me/BotFather).
2. Send `/newbot` and follow the prompts (display name + username ending in `bot`).
3. BotFather replies with a token like `123456:ABC-DEF...`.
4. Put it in `stack/telegram_notifier_bot_token.yaml` (from the `.example` file):

```yaml
app:
  telegram:
    bot_token: "YOUR_BOT_TOKEN"
```

Keep that file local (it is gitignored).

**Chat id** (where alerts are sent)

1. Start a chat with your new bot (press Start), or add it to a group.
2. Send any message in that chat.
3. Open in a browser (replace with your token):

   `https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates`

4. In the JSON, find `"chat":{"id": ...}` — that number is your `chat_id`
   (for groups it is often negative).
5. Set it in `stack/telegram_notifier.yaml`:

```yaml
app:
  endpoints:
    ops_alerts:
      chat_id: "YOUR_CHAT_ID"
```

Use a string in YAML even though the value is numeric.