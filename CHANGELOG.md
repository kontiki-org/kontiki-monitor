# Changelog

## [0.1.0] - 2026-07-21

Initial public release.

- `kontiki-monitor`: Registry fleet expectations and bus lifecycle events →
  `alert.normalized` (silences via RPC/HTTP).
- `host-check-service`: per-host disk occupation (warning/critical) and
  unavailable paths → `alert.normalized`.
- Embedded Compose stack (Registry, Boomerang notifiers, demo-app, MailHog).
- Behave integration suites for monitor and host-check.
