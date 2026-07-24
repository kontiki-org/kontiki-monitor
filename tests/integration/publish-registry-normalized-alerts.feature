@kontiki_monitor
Feature: Publish Kontiki Registry events as normalized alerts
  In order to feed the Boomerang alerting pipeline
  As the kontiki-monitor
  I want registry lifecycle events to become alert.normalized events on the bus

  The When steps publish Kontiki 1.1.0 registry bus events (registry.instance.*, registry.exception.recorded).
  The Then steps assert the connector's NormalizedAlert shape (event_type, attributes for subscriptions).

  Scenario: Emit alert.normalized when an instance is registered
    Given the kontiki-monitor is running with the following configuration
      """
      kontiki:
        amqp:
          url: amqp://guest:guest@localhost/
      logging:
        version: 1
        disable_existing_loggers: false
        formatters:
          default:
            format: "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
            datefmt: "%Y-%m-%d %H:%M:%S"
        handlers:
          file:
            class: logging.FileHandler
            formatter: default
            filename: /tmp/kontiki-monitor.log
            level: INFO
        root:
          level: DEBUG
          handlers:
            - file
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
        }
      }
      """

  Scenario: Emit alert.normalized when an instance is deregistered
    Given the kontiki-monitor is running with the following configuration
      """
      kontiki:
        amqp:
          url: amqp://guest:guest@localhost/
      logging:
        version: 1
        disable_existing_loggers: false
        formatters:
          default:
            format: "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
            datefmt: "%Y-%m-%d %H:%M:%S"
        handlers:
          file:
            class: logging.FileHandler
            formatter: default
            filename: /tmp/kontiki-monitor.log
            level: INFO
        root:
          level: DEBUG
          handlers:
            - file
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
        }
      }
      """

  Scenario: Emit alert.normalized when an instance becomes degraded
    Given the kontiki-monitor is running with the following configuration
      """
      kontiki:
        amqp:
          url: amqp://guest:guest@localhost/
      logging:
        version: 1
        disable_existing_loggers: false
        formatters:
          default:
            format: "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
            datefmt: "%Y-%m-%d %H:%M:%S"
        handlers:
          file:
            class: logging.FileHandler
            formatter: default
            filename: /tmp/kontiki-monitor.log
            level: INFO
        root:
          level: DEBUG
          handlers:
            - file
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
        }
      }
      """

  Scenario: Include status_changed reason on alert.normalized when present
    Given the kontiki-monitor is running with the following configuration
      """
      kontiki:
        amqp:
          url: amqp://guest:guest@localhost/
      logging:
        version: 1
        disable_existing_loggers: false
        formatters:
          default:
            format: "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
            datefmt: "%Y-%m-%d %H:%M:%S"
        handlers:
          file:
            class: logging.FileHandler
            formatter: default
            filename: /tmp/kontiki-monitor.log
            level: INFO
        root:
          level: DEBUG
          handlers:
            - file
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
        }
      }
      """

  Scenario: Emit alert.normalized when the registry records an exception
    Given the kontiki-monitor is running with the following configuration
      """
      kontiki:
        amqp:
          url: amqp://guest:guest@localhost/
      logging:
        version: 1
        disable_existing_loggers: false
        formatters:
          default:
            format: "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
            datefmt: "%Y-%m-%d %H:%M:%S"
        handlers:
          file:
            class: logging.FileHandler
            formatter: default
            filename: /tmp/kontiki-monitor.log
            level: INFO
        root:
          level: DEBUG
          handlers:
            - file
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
          "exception_type": "RuntimeError"
        }
      }
      """
