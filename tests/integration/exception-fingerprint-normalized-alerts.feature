@kontiki_monitor @exception_fingerprint
Feature: Fingerprint registry exceptions as open/recover alerts
  In order to avoid spamming notifiers with the same Registry exception
  As the kontiki-monitor
  I want exception_recorded NormalizedAlert events on fingerprint edges only

  Payload shape is Boomerang NormalizedAlert (all schema fields in Then
  DocStrings). Producer convention matches fleet and disk: stable alert_id and
  attributes.resolution open|recovered.

  Fingerprint key: (service_name, exception_type, message). instance_id is not
  in the key. alert_id is exception:{service_name}:{short_hash} with short_hash
  = sha256("{exception_type}\0{message}")[:12].
  Recover after exception_recover_after_seconds without that fingerprint.
  In-memory only (process restart clears state).
  Use "*" in Then payloads for values not fixed in the scenario (e.g. wall-clock
  occurred_at on recover).

  Background:
    Given the kontiki-monitor is running with the following configuration
      """
      kontiki:
        amqp:
          url: amqp://guest:guest@localhost/
      logging:
        directory: /tmp
        handlers:
          file:
            class: logging.handlers.RotatingFileHandler
            level: INFO
            maxBytes: 10485760
            backupCount: 5
        root:
          handlers: [file]
          level: INFO
      kontiki-monitor:
        category: "kontiki.registry"
        poll_interval_seconds: 2
        exception_recover_after_seconds: 3
      """

  Scenario: Open exception_recorded once for a fingerprint
    When a "registry.exception.recorded" event is published with payload
      """
      {
        "service_name": "payment-service",
        "instance_id": "11111111-2222-3333-4444-555555555555",
        "exception_type": "RuntimeError",
        "message": "SMTP connection refused",
        "timestamp": "2026-07-15T12:02:00Z"
      }
      """
    Then an "alert.normalized" event is published with payload
      """
      {
        "schema_version": "1.0",
        "alert_id": "exception:payment-service:f406e9080e69",
        "source": "kontiki-monitor",
        "category": "kontiki.registry",
        "event_type": "exception_recorded",
        "severity": "severe",
        "occurred_at": "2026-07-15T12:02:00Z",
        "title": "payment-service RuntimeError",
        "body": "SMTP connection refused",
        "areas": [],
        "attributes": {
          "service_name": "payment-service",
          "instance_id": "11111111-2222-3333-4444-555555555555",
          "exception_type": "RuntimeError",
          "resolution": "open"
        },
        "expires_at": null
      }
      """

  Scenario: Do not re-publish while the same fingerprint stays open
    When a "registry.exception.recorded" event is published with payload
      """
      {
        "service_name": "payment-service",
        "instance_id": "11111111-2222-3333-4444-555555555555",
        "exception_type": "RuntimeError",
        "message": "SMTP connection refused",
        "timestamp": "2026-07-15T12:02:00Z"
      }
      """
    Then an "alert.normalized" event is published with payload
      """
      {
        "schema_version": "1.0",
        "alert_id": "exception:payment-service:f406e9080e69",
        "source": "kontiki-monitor",
        "category": "kontiki.registry",
        "event_type": "exception_recorded",
        "severity": "severe",
        "occurred_at": "2026-07-15T12:02:00Z",
        "title": "payment-service RuntimeError",
        "body": "SMTP connection refused",
        "areas": [],
        "attributes": {
          "service_name": "payment-service",
          "instance_id": "11111111-2222-3333-4444-555555555555",
          "exception_type": "RuntimeError",
          "resolution": "open"
        },
        "expires_at": null
      }
      """
    When a "registry.exception.recorded" event is published with payload
      """
      {
        "service_name": "payment-service",
        "instance_id": "99999999-8888-7777-6666-555555555555",
        "exception_type": "RuntimeError",
        "message": "SMTP connection refused",
        "timestamp": "2026-07-15T12:03:00Z"
      }
      """
    Then no "alert.normalized" event is published

  Scenario: A different message opens a second fingerprint
    When a "registry.exception.recorded" event is published with payload
      """
      {
        "service_name": "payment-service",
        "instance_id": "11111111-2222-3333-4444-555555555555",
        "exception_type": "RuntimeError",
        "message": "SMTP connection refused",
        "timestamp": "2026-07-15T12:02:00Z"
      }
      """
    Then an "alert.normalized" event is published with payload
      """
      {
        "schema_version": "1.0",
        "alert_id": "exception:payment-service:f406e9080e69",
        "source": "kontiki-monitor",
        "category": "kontiki.registry",
        "event_type": "exception_recorded",
        "severity": "severe",
        "occurred_at": "2026-07-15T12:02:00Z",
        "title": "payment-service RuntimeError",
        "body": "SMTP connection refused",
        "areas": [],
        "attributes": {
          "service_name": "payment-service",
          "instance_id": "11111111-2222-3333-4444-555555555555",
          "exception_type": "RuntimeError",
          "resolution": "open"
        },
        "expires_at": null
      }
      """
    When a "registry.exception.recorded" event is published with payload
      """
      {
        "service_name": "payment-service",
        "instance_id": "11111111-2222-3333-4444-555555555555",
        "exception_type": "RuntimeError",
        "message": "quota exceeded",
        "timestamp": "2026-07-15T12:04:00Z"
      }
      """
    Then an "alert.normalized" event is published with payload
      """
      {
        "schema_version": "1.0",
        "alert_id": "exception:payment-service:018d61cdb26b",
        "source": "kontiki-monitor",
        "category": "kontiki.registry",
        "event_type": "exception_recorded",
        "severity": "severe",
        "occurred_at": "2026-07-15T12:04:00Z",
        "title": "payment-service RuntimeError",
        "body": "quota exceeded",
        "areas": [],
        "attributes": {
          "service_name": "payment-service",
          "instance_id": "11111111-2222-3333-4444-555555555555",
          "exception_type": "RuntimeError",
          "resolution": "open"
        },
        "expires_at": null
      }
      """

  Scenario: Recover when the fingerprint is not seen for the recover window
    When a "registry.exception.recorded" event is published with payload
      """
      {
        "service_name": "payment-service",
        "instance_id": "11111111-2222-3333-4444-555555555555",
        "exception_type": "RuntimeError",
        "message": "SMTP connection refused",
        "timestamp": "2026-07-15T12:02:00Z"
      }
      """
    Then an "alert.normalized" event is published with payload
      """
      {
        "schema_version": "1.0",
        "alert_id": "exception:payment-service:f406e9080e69",
        "source": "kontiki-monitor",
        "category": "kontiki.registry",
        "event_type": "exception_recorded",
        "severity": "severe",
        "occurred_at": "2026-07-15T12:02:00Z",
        "title": "payment-service RuntimeError",
        "body": "SMTP connection refused",
        "areas": [],
        "attributes": {
          "service_name": "payment-service",
          "instance_id": "11111111-2222-3333-4444-555555555555",
          "exception_type": "RuntimeError",
          "resolution": "open"
        },
        "expires_at": null
      }
      """
    When an exception fingerprint poll runs after the recover window
    Then an "alert.normalized" event is published with payload
      """
      {
        "schema_version": "1.0",
        "alert_id": "exception:payment-service:f406e9080e69",
        "source": "kontiki-monitor",
        "category": "kontiki.registry",
        "event_type": "exception_recorded",
        "severity": "low",
        "occurred_at": "*",
        "title": "payment-service RuntimeError",
        "body": "SMTP connection refused",
        "areas": [],
        "attributes": {
          "service_name": "payment-service",
          "instance_id": "11111111-2222-3333-4444-555555555555",
          "exception_type": "RuntimeError",
          "resolution": "recovered"
        },
        "expires_at": null
      }
      """
