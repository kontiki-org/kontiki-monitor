# Changelog

## [Unreleased]

- Demo workload owned here: `testing/demo_app` (`kontiki-demo-app`), Compose
  image `kontiki-monitor:local`, Makefile targets via local CLI
  (`demo-app-raise-exception` included).
- Ops stack: `kontiki-boomerang` `>=0.3.0,<0.4.0`; Telegram
  `app.telegram.category_icons` (`kontiki.registry`) in
  `stack/telegram_notifier.yaml`.

## [0.1.0] - 2026-07-22

Initial public release.

- `kontiki-monitor`: Registry fleet expectations and bus lifecycle events →
  `alert.normalized` (silences via RPC/HTTP).
- `host-check-service`: per-host disk occupation (warning/critical) and
  unavailable paths → `alert.normalized`.
- Requires Kontiki `>=1.4.0` (registration `group`). Ops stack services set
  `kontiki.registration.group: platform` in their own YAML; `demo-app` keeps
  the default `business` (kontiki-tui defaults to the business view).
- Embedded Compose stack (Registry, Boomerang notifiers, demo-app, MailHog).
- Dev dependency `kontiki-tui>=0.2.0`; `make tui` for optional stack observation.
- Behave integration suites for monitor and host-check.
