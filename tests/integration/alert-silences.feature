@kontiki_monitor @alert_silences
Feature: Silence alerts for a service on demand
  In order to mute noise during maintenance or debugging
  As an operator of kontiki-monitor
  I want to turn silences on and off per service_name over RPC and HTTP

  Silences are on/off only (no duration). While silenced, fleet skips that service
  (open state dropped without recover). Lifecycle registry events for that service
  are not published. Clear is mandatory; nothing auto-expires.
  HTTP mirrors the Registry-style surface (GET/POST/DELETE /silences).

  Background:
    Given the kontiki-monitor is running with the following configuration
      """
      kontiki:
        amqp:
          url: amqp://guest:guest@localhost/
        http:
          address: 127.0.0.1
          port: 8091
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
        expected_services:
          alpha-service:
            min_active: 1
      """

  Scenario: List silences via RPC after add and clear; add is idempotent
    When I call the RPC list_silences on the kontiki-monitor with the following arguments
      """
      {}
      """
    Then the kontiki-monitor RPC call succeeds
    And the kontiki-monitor RPC response is
      """
      []
      """
    When I call the RPC add_silence on the kontiki-monitor with the following arguments
      """
      {
        "service_name": "alpha-service"
      }
      """
    Then the kontiki-monitor RPC call succeeds
    And the kontiki-monitor RPC response is
      """
      {
        "service_name": "alpha-service"
      }
      """
    When I call the RPC add_silence on the kontiki-monitor with the following arguments
      """
      {
        "service_name": "alpha-service"
      }
      """
    Then the kontiki-monitor RPC call succeeds
    And the kontiki-monitor RPC response is
      """
      {
        "service_name": "alpha-service"
      }
      """
    When I call the RPC list_silences on the kontiki-monitor with the following arguments
      """
      {}
      """
    Then the kontiki-monitor RPC call succeeds
    And the kontiki-monitor RPC response is
      """
      [
        {
          "service_name": "alpha-service"
        }
      ]
      """
    When I call the RPC clear_silence on the kontiki-monitor with the following arguments
      """
      {
        "service_name": "alpha-service"
      }
      """
    Then the kontiki-monitor RPC call succeeds
    And the kontiki-monitor RPC response is
      """
      {
        "cleared": true
      }
      """
    When I call the RPC clear_silence on the kontiki-monitor with the following arguments
      """
      {
        "service_name": "alpha-service"
      }
      """
    Then the kontiki-monitor RPC call succeeds
    And the kontiki-monitor RPC response is
      """
      {
        "cleared": false
      }
      """
    When I call the RPC list_silences on the kontiki-monitor with the following arguments
      """
      {}
      """
    Then the kontiki-monitor RPC call succeeds
    And the kontiki-monitor RPC response is
      """
      []
      """

  Scenario: Manage silences over HTTP the same way as RPC
    When I call POST on the kontiki-monitor on http://127.0.0.1:8091/silences with the following request
      """
      {
        "payload": {
          "service_name": "alpha-service"
        }
      }
      """
    Then the kontiki-monitor HTTP call succeeds with status 200
    And the kontiki-monitor HTTP response is
      """
      {
        "service_name": "alpha-service"
      }
      """
    When I call GET on the kontiki-monitor on http://127.0.0.1:8091/silences with the following request
      """
      {
        "payload": null
      }
      """
    Then the kontiki-monitor HTTP call succeeds with status 200
    And the kontiki-monitor HTTP response is
      """
      [
        {
          "service_name": "alpha-service"
        }
      ]
      """
    When I call the RPC list_silences on the kontiki-monitor with the following arguments
      """
      {}
      """
    Then the kontiki-monitor RPC call succeeds
    And the kontiki-monitor RPC response is
      """
      [
        {
          "service_name": "alpha-service"
        }
      ]
      """
    When I call DELETE on the kontiki-monitor on http://127.0.0.1:8091/silences/alpha-service with the following request
      """
      {
        "payload": null
      }
      """
    Then the kontiki-monitor HTTP call succeeds with status 200
    And the kontiki-monitor HTTP response is
      """
      {
        "cleared": true
      }
      """
    When I call GET on the kontiki-monitor on http://127.0.0.1:8091/silences with the following request
      """
      {
        "payload": null
      }
      """
    Then the kontiki-monitor HTTP call succeeds with status 200
    And the kontiki-monitor HTTP response is
      """
      []
      """

  @pb
  Scenario: Silenced service does not open a fleet missing alert until cleared
    When I call the RPC add_silence on the kontiki-monitor with the following arguments
      """
      {
        "service_name": "alpha-service"
      }
      """
    Then the kontiki-monitor RPC call succeeds
    When a fleet poll observes the Service Registry returning the following services
      """
      {}
      """
    Then no "alert.normalized" event is published
    When I call the RPC clear_silence on the kontiki-monitor with the following arguments
      """
      {
        "service_name": "alpha-service"
      }
      """
    Then the kontiki-monitor RPC call succeeds
    When a fleet poll observes the Service Registry returning the following services
      """
      {}
      """
    Then an "alert.normalized" event is published with payload
      """
      {
        "source": "kontiki-monitor",
        "category": "kontiki.registry",
        "event_type": "expected_service_missing",
        "severity": "critical",
        "alert_id": "fleet:alpha-service:missing",
        "title": "alpha-service missing from registry",
        "attributes": {
          "service_name": "alpha-service",
          "min_active": 1,
          "active_count": 0,
          "observed_statuses": "",
          "resolution": "open"
        }
      }
      """

  Scenario: Silencing an open fleet condition does not publish recover
    When a fleet poll observes the Service Registry returning the following services
      """
      {}
      """
    Then an "alert.normalized" event is published with payload
      """
      {
        "source": "kontiki-monitor",
        "category": "kontiki.registry",
        "event_type": "expected_service_missing",
        "severity": "critical",
        "alert_id": "fleet:alpha-service:missing",
        "title": "alpha-service missing from registry",
        "attributes": {
          "service_name": "alpha-service",
          "min_active": 1,
          "active_count": 0,
          "observed_statuses": "",
          "resolution": "open"
        }
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
    When a fleet poll observes the Service Registry returning the following services
      """
      {}
      """
    Then no "alert.normalized" event is published
    When I call the RPC clear_silence on the kontiki-monitor with the following arguments
      """
      {
        "service_name": "alpha-service"
      }
      """
    Then the kontiki-monitor RPC call succeeds
    When a fleet poll observes the Service Registry returning the following services
      """
      {}
      """
    Then an "alert.normalized" event is published with payload
      """
      {
        "source": "kontiki-monitor",
        "category": "kontiki.registry",
        "event_type": "expected_service_missing",
        "severity": "critical",
        "alert_id": "fleet:alpha-service:missing",
        "title": "alpha-service missing from registry",
        "attributes": {
          "service_name": "alpha-service",
          "min_active": 1,
          "active_count": 0,
          "observed_statuses": "",
          "resolution": "open"
        }
      }
      """

  Scenario: Silenced service drops lifecycle alerts; other services still publish
    When I call the RPC add_silence on the kontiki-monitor with the following arguments
      """
      {
        "service_name": "payment-service"
      }
      """
    Then the kontiki-monitor RPC call succeeds
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
    Then no "alert.normalized" event is published
    When a "registry.instance.status_changed" event is published with payload
      """
      {
        "service_name": "email-notifier-service",
        "instance_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
        "previous_status": "active",
        "new_status": "degraded",
        "timestamp": "2026-07-15T12:01:00Z"
      }
      """
    Then an "alert.normalized" event is published with payload
      """
      {
        "source": "kontiki-monitor",
        "category": "kontiki.registry",
        "event_type": "instance_state_changed",
        "severity": "severe",
        "occurred_at": "2026-07-15T12:01:00Z",
        "title": "email-notifier-service state active → degraded",
        "body": "Instance aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee changed from active to degraded.",
        "areas": [],
        "attributes": {
          "service_name": "email-notifier-service",
          "instance_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
          "previous_state": "active",
          "new_state": "degraded"
        }
      }
      """

  Scenario: Clearing a silence resumes lifecycle alerts for that service
    When I call the RPC add_silence on the kontiki-monitor with the following arguments
      """
      {
        "service_name": "payment-service"
      }
      """
    Then the kontiki-monitor RPC call succeeds
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
    Then no "alert.normalized" event is published
    When I call the RPC clear_silence on the kontiki-monitor with the following arguments
      """
      {
        "service_name": "payment-service"
      }
      """
    Then the kontiki-monitor RPC call succeeds
    When a "registry.instance.status_changed" event is published with payload
      """
      {
        "service_name": "payment-service",
        "instance_id": "11111111-2222-3333-4444-555555555555",
        "previous_status": "active",
        "new_status": "degraded",
        "timestamp": "2026-07-15T12:02:00Z"
      }
      """
    Then an "alert.normalized" event is published with payload
      """
      {
        "source": "kontiki-monitor",
        "category": "kontiki.registry",
        "event_type": "instance_state_changed",
        "severity": "severe",
        "occurred_at": "2026-07-15T12:02:00Z",
        "title": "payment-service state active → degraded",
        "body": "Instance 11111111-2222-3333-4444-555555555555 changed from active to degraded.",
        "areas": [],
        "attributes": {
          "service_name": "payment-service",
          "instance_id": "11111111-2222-3333-4444-555555555555",
          "previous_state": "active",
          "new_state": "degraded"
        }
      }
      """
