@kontiki_monitor @list_open_alerts
Feature: List currently open ops alerts on kontiki-monitor
  In order to see fleet and exception conditions that are still true
  As an operator querying kontiki-monitor
  I want list_open_alerts to return the open NormalizedAlert snapshots

  RPC list_open_alerts {} returns a JSON list sorted by alert_id.
  Each item is a full NormalizedAlert with attributes.resolution open,
  the same object as the open alert.normalized edge (not a fresh now()).
  The RPC does not publish. Lifecycle registry events are not listed.
  Process restart clears the list. Monitor silences drop matching opens
  without a recover publish.

  Background:
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
        poll_interval_seconds: 8
        exception_recover_after_seconds: 3
        expected_services:
          alpha-service:
            min_active: 1
      """

  Scenario: list_open_alerts is empty before any open
    When I call the RPC list_open_alerts on the kontiki-monitor with the following arguments
      """
      {}
      """
    Then the kontiki-monitor RPC call succeeds
    And the kontiki-monitor RPC response is
      """
      []
      """

  Scenario: Open fleet missing appears in list_open_alerts
    When a fleet poll observes the Service Registry returning the following services
      """
      {}
      """
    Then an "alert.normalized" event is published with payload
      """
      {
        "schema_version": "1.0",
        "alert_id": "fleet:alpha-service:missing",
        "source": "kontiki-monitor",
        "category": "kontiki.registry",
        "event_type": "expected_service_missing",
        "severity": "critical",
        "occurred_at": "*",
        "title": "alpha-service missing from registry",
        "body": "alpha-service missing from registry",
        "areas": [],
        "attributes": {
          "service_name": "alpha-service",
          "min_active": 1,
          "active_count": 0,
          "observed_statuses": "",
          "resolution": "open"
        },
        "expires_at": null
      }
      """
    When I call the RPC list_open_alerts on the kontiki-monitor with the following arguments
      """
      {}
      """
    Then the kontiki-monitor RPC call succeeds
    And the kontiki-monitor RPC response is
      """
      [
        {
          "schema_version": "1.0",
          "alert_id": "fleet:alpha-service:missing",
          "source": "kontiki-monitor",
          "category": "kontiki.registry",
          "event_type": "expected_service_missing",
          "severity": "critical",
          "occurred_at": "*",
          "title": "alpha-service missing from registry",
          "body": "alpha-service missing from registry",
          "areas": [],
          "attributes": {
            "service_name": "alpha-service",
            "min_active": 1,
            "active_count": 0,
            "observed_statuses": "",
            "resolution": "open"
          },
          "expires_at": null
        }
      ]
      """

  Scenario: Recovered fleet missing is gone from list_open_alerts
    When a fleet poll observes the Service Registry returning the following services
      """
      {}
      """
    Then an "alert.normalized" event is published with payload
      """
      {
        "schema_version": "1.0",
        "alert_id": "fleet:alpha-service:missing",
        "source": "kontiki-monitor",
        "category": "kontiki.registry",
        "event_type": "expected_service_missing",
        "severity": "critical",
        "occurred_at": "*",
        "title": "alpha-service missing from registry",
        "body": "alpha-service missing from registry",
        "areas": [],
        "attributes": {
          "service_name": "alpha-service",
          "min_active": 1,
          "active_count": 0,
          "observed_statuses": "",
          "resolution": "open"
        },
        "expires_at": null
      }
      """
    When a fleet poll observes the Service Registry returning the following services
      """
      {
        "alpha-service": {
          "inst-1": {
            "status": "active",
            "metadata": {
              "service_name": "alpha-service",
              "instance_id": "inst-1",
              "host": "worker-01",
              "pid": 1001,
              "service_version": "1.0.0",
              "heartbeat_interval": 60
            }
          }
        }
      }
      """
    Then an "alert.normalized" event is published with payload
      """
      {
        "schema_version": "1.0",
        "alert_id": "fleet:alpha-service:missing",
        "source": "kontiki-monitor",
        "category": "kontiki.registry",
        "event_type": "expected_service_missing",
        "severity": "low",
        "occurred_at": "*",
        "title": "alpha-service recovered",
        "body": "alpha-service recovered",
        "areas": [],
        "attributes": {
          "service_name": "alpha-service",
          "min_active": 1,
          "active_count": 1,
          "observed_statuses": "inst-1=active",
          "resolution": "recovered"
        },
        "expires_at": null
      }
      """
    When I call the RPC list_open_alerts on the kontiki-monitor with the following arguments
      """
      {}
      """
    Then the kontiki-monitor RPC call succeeds
    And the kontiki-monitor RPC response is
      """
      []
      """

  Scenario: Silencing an open fleet condition removes it from list_open_alerts
    When a fleet poll observes the Service Registry returning the following services
      """
      {}
      """
    Then an "alert.normalized" event is published with payload
      """
      {
        "schema_version": "1.0",
        "alert_id": "fleet:alpha-service:missing",
        "source": "kontiki-monitor",
        "category": "kontiki.registry",
        "event_type": "expected_service_missing",
        "severity": "critical",
        "occurred_at": "*",
        "title": "alpha-service missing from registry",
        "body": "alpha-service missing from registry",
        "areas": [],
        "attributes": {
          "service_name": "alpha-service",
          "min_active": 1,
          "active_count": 0,
          "observed_statuses": "",
          "resolution": "open"
        },
        "expires_at": null
      }
      """
    When I call the RPC add_silence on the kontiki-monitor with the following arguments
      """
      {
        "service_name": "alpha-service"
      }
      """
    Then the kontiki-monitor RPC call succeeds
    And no "alert.normalized" event is published
    When I call the RPC list_open_alerts on the kontiki-monitor with the following arguments
      """
      {}
      """
    Then the kontiki-monitor RPC call succeeds
    And the kontiki-monitor RPC response is
      """
      []
      """

  Scenario: Open exception fingerprint appears in list_open_alerts
    When a fleet poll observes the Service Registry returning the following services
      """
      {
        "alpha-service": {
          "inst-1": {
            "status": "active"
          }
        }
      }
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
    When I call the RPC list_open_alerts on the kontiki-monitor with the following arguments
      """
      {}
      """
    Then the kontiki-monitor RPC call succeeds
    And the kontiki-monitor RPC response is
      """
      [
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
      ]
      """

  Scenario: Recovered exception fingerprint is gone from list_open_alerts
    When a fleet poll observes the Service Registry returning the following services
      """
      {
        "alpha-service": {
          "inst-1": {
            "status": "active"
          }
        }
      }
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
    When I call the RPC list_open_alerts on the kontiki-monitor with the following arguments
      """
      {}
      """
    Then the kontiki-monitor RPC call succeeds
    And the kontiki-monitor RPC response is
      """
      []
      """

  Scenario: Open fleet and exception alerts are listed sorted by alert_id
    When a fleet poll observes the Service Registry returning the following services
      """
      {}
      """
    Then an "alert.normalized" event is published with payload
      """
      {
        "schema_version": "1.0",
        "alert_id": "fleet:alpha-service:missing",
        "source": "kontiki-monitor",
        "category": "kontiki.registry",
        "event_type": "expected_service_missing",
        "severity": "critical",
        "occurred_at": "*",
        "title": "alpha-service missing from registry",
        "body": "alpha-service missing from registry",
        "areas": [],
        "attributes": {
          "service_name": "alpha-service",
          "min_active": 1,
          "active_count": 0,
          "observed_statuses": "",
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
    When I call the RPC list_open_alerts on the kontiki-monitor with the following arguments
      """
      {}
      """
    Then the kontiki-monitor RPC call succeeds
    And the kontiki-monitor RPC response is
      """
      [
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
        },
        {
          "schema_version": "1.0",
          "alert_id": "fleet:alpha-service:missing",
          "source": "kontiki-monitor",
          "category": "kontiki.registry",
          "event_type": "expected_service_missing",
          "severity": "critical",
          "occurred_at": "*",
          "title": "alpha-service missing from registry",
          "body": "alpha-service missing from registry",
          "areas": [],
          "attributes": {
            "service_name": "alpha-service",
            "min_active": 1,
            "active_count": 0,
            "observed_statuses": "",
            "resolution": "open"
          },
          "expires_at": null
        }
      ]
      """
