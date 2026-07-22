# Changelog

## Unreleased

- Requires Kontiki `>=1.4.0` (registration `group`).
- Stack / service configs: each ops service sets `kontiki.registration.group:
  platform` in its own YAML (Kontiki merge does not override conflicting leaves).
  `demo-app` omits it → default `business`.
- Dev dependency `kontiki-tui>=0.2.0`; `make tui` for optional stack observation.

## [0.1.0] - 2026-07-21

Initial public release.

- `kontiki-monitor`: Registry fleet expectations and bus lifecycle events →
  `alert.normalized` (silences via RPC/HTTP).
- `host-check-service`: per-host disk occupation (warning/critical) and
  unavailable paths → `alert.normalized`.
- Embedded Compose stack (Registry, Boomerang notifiers, demo-app, MailHog).
- Behave integration suites for monitor and host-check.
