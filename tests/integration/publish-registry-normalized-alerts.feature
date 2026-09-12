@kontiki_monitor
Feature: Publish Kontiki Registry events as normalized alerts
  In order to feed the Boomerang alerting pipeline
  As the kontiki-monitor
  I want registry lifecycle events to become alert.normalized events on the bus

  Then payloads are full Boomerang NormalizedAlert objects (all schema fields).
  exception_recorded open matches exception-fingerprint-normalized-alerts.feature
  (stable alert_id, attributes.resolution=open).

  Scenario: Emit alert.normalized when an instance is registered
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
        poll_interval_seconds: 30
      """
    When a "registry.instance.registered" event is published with payload
      """
      {
        "service_name": "email-notifier-service",
        "instance_id": "11111111-2222-3333-4444-555555555555",
        "host": "worker-01",
        "service_version": "1.0.0",
        "timestamp": "2026-07-15T12:00:00Z"
      }
      """
    Then an "alert.normalized" event is published with payload
      """
      {
        "schema_version": "1.0",
        "alert_id": "registry:email-notifier-service:11111111-2222-3333-4444-555555555555:registered:2026-07-15T12:00:00+00:00",
        "source": "kontiki-monitor",
        "category": "kontiki.registry",
        "event_type": "instance_registered",
        "severity": "low",
        "occurred_at": "2026-07-15T12:00:00Z",
        "title": "email-notifier-service instance registered on worker-01",
        "body": "email-notifier-service instance registered on worker-01 (version 1.0.0).",
        "areas": [],
        "attributes": {
          "service_name": "email-notifier-service",
          "instance_id": "11111111-2222-3333-4444-555555555555",
          "host": "worker-01",
          "version": "1.0.0"
        },
        "expires_at": null
      }
      """

  Scenario: Emit alert.normalized when an instance is deregistered
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
        poll_interval_seconds: 30
      """
    When a "registry.instance.deregistered" event is published with payload
      """
      {
        "service_name": "email-notifier-service",
        "instance_id": "11111111-2222-3333-4444-555555555555",
        "timestamp": "2026-07-15T12:01:00Z"
      }
      """
    Then an "alert.normalized" event is published with payload
      """
      {
        "schema_version": "1.0",
        "alert_id": "registry:email-notifier-service:11111111-2222-3333-4444-555555555555:unregistered:2026-07-15T12:01:00+00:00",
        "source": "kontiki-monitor",
        "category": "kontiki.registry",
        "event_type": "instance_unregistered",
        "severity": "low",
        "occurred_at": "2026-07-15T12:01:00Z",
        "title": "email-notifier-service instance unregistered",
        "body": "email-notifier-service instance unregistered",
        "areas": [],
        "attributes": {
          "service_name": "email-notifier-service",
          "instance_id": "11111111-2222-3333-4444-555555555555"
        },
        "expires_at": null
      }
      """

  Scenario: Emit alert.normalized when an instance becomes degraded
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
        poll_interval_seconds: 30
      """
    When a "registry.instance.status_changed" event is published with payload
      """
      {
        "service_name": "payment-service",
        "instance_id": "11111111-2222-3333-4444-555555555555",
        "previous_status": "active",
        "new_status": "degraded",
        "timestamp": "2026-07-15T12:00:00Z"
      }
      """
    Then an "alert.normalized" event is published with payload
      """
      {
        "schema_version": "1.0",
        "alert_id": "registry:payment-service:11111111-2222-3333-4444-555555555555:state:active:degraded:2026-07-15T12:00:00+00:00",
        "source": "kontiki-monitor",
        "category": "kontiki.registry",
        "event_type": "instance_state_changed",
        "severity": "severe",
        "occurred_at": "2026-07-15T12:00:00Z",
        "title": "payment-service state active → degraded",
        "body": "payment-service state active → degraded",
        "areas": [],
        "attributes": {
          "service_name": "payment-service",
          "instance_id": "11111111-2222-3333-4444-555555555555",
          "previous_state": "active",
          "new_state": "degraded"
        },
        "expires_at": null
      }
      """

  Scenario: Include status_changed reason on alert.normalized when present
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
        poll_interval_seconds: 30
      """
    When a "registry.instance.status_changed" event is published with payload
      """
      {
        "service_name": "payment-service",
        "instance_id": "11111111-2222-3333-4444-555555555555",
        "previous_status": "active",
        "new_status": "degraded",
        "reason": "demo degrade requested",
        "timestamp": "2026-07-15T12:00:00Z"
      }
      """
    Then an "alert.normalized" event is published with payload
      """
      {
        "schema_version": "1.0",
        "alert_id": "registry:payment-service:11111111-2222-3333-4444-555555555555:state:active:degraded:2026-07-15T12:00:00+00:00",
        "source": "kontiki-monitor",
        "category": "kontiki.registry",
        "event_type": "instance_state_changed",
        "severity": "severe",
        "occurred_at": "2026-07-15T12:00:00Z",
        "title": "payment-service state active → degraded",
        "body": "payment-service state active → degraded",
        "areas": [],
        "attributes": {
          "service_name": "payment-service",
          "instance_id": "11111111-2222-3333-4444-555555555555",
          "previous_state": "active",
          "new_state": "degraded",
          "reason": "demo degrade requested"
        },
        "expires_at": null
      }
      """

  Scenario: Emit alert.normalized when the registry records an exception
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
        poll_interval_seconds: 30
      """
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
