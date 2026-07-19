@kontiki_monitor @fleet_state
Feature: Detect fleet expectation failures as normalized alerts
  In order to alert when expected Kontiki services are missing or under-provisioned
  As the kontiki-monitor
  I want judgments from Registry.get_services snapshots to become alert.normalized events on edges only

  Judgment runs on each fleet poll. The When step is that poll observing a get_services snapshot.
  Only services listed in expected_services are watched. missing wins over insufficient.
  Open and recover use a stable alert_id; recover sets resolution=recovered.

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
        expected_services:
          alpha-service:
            min_active: 1
      """

  Scenario: Open expected_service_missing once and do not re-publish while it stays open
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
    When a fleet poll observes the Service Registry returning the following services
      """
      {}
      """
    Then no "alert.normalized" event is published

  Scenario: Recover expected_service_missing when the service reappears
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
        "source": "kontiki-monitor",
        "category": "kontiki.registry",
        "event_type": "expected_service_missing",
        "severity": "low",
        "alert_id": "fleet:alpha-service:missing",
        "title": "alpha-service recovered",
        "attributes": {
          "service_name": "alpha-service",
          "min_active": 1,
          "active_count": 1,
          "observed_statuses": "inst-1=active",
          "resolution": "recovered"
        }
      }
      """

  Scenario: Open insufficient_active_instances when present but below min_active
    When a fleet poll observes the Service Registry returning the following services
      """
      {
        "alpha-service": {
          "inst-1": {
            "status": "down",
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
        "source": "kontiki-monitor",
        "category": "kontiki.registry",
        "event_type": "insufficient_active_instances",
        "severity": "severe",
        "alert_id": "fleet:alpha-service:insufficient",
        "title": "alpha-service insufficient active instances",
        "attributes": {
          "service_name": "alpha-service",
          "min_active": 1,
          "active_count": 0,
          "observed_statuses": "inst-1=down",
          "resolution": "open"
        }
      }
      """

  Scenario: Recover insufficient_active_instances when active_count meets min_active
    When a fleet poll observes the Service Registry returning the following services
      """
      {
        "alpha-service": {
          "inst-1": {
            "status": "down",
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
        "source": "kontiki-monitor",
        "category": "kontiki.registry",
        "event_type": "insufficient_active_instances",
        "severity": "severe",
        "alert_id": "fleet:alpha-service:insufficient",
        "title": "alpha-service insufficient active instances",
        "attributes": {
          "service_name": "alpha-service",
          "min_active": 1,
          "active_count": 0,
          "observed_statuses": "inst-1=down",
          "resolution": "open"
        }
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
        "source": "kontiki-monitor",
        "category": "kontiki.registry",
        "event_type": "insufficient_active_instances",
        "severity": "low",
        "alert_id": "fleet:alpha-service:insufficient",
        "title": "alpha-service recovered",
        "attributes": {
          "service_name": "alpha-service",
          "min_active": 1,
          "active_count": 1,
          "observed_statuses": "inst-1=active",
          "resolution": "recovered"
        }
      }
      """

  Scenario: Prefer expected_service_missing over insufficient when the service is absent
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
    And no "alert.normalized" event is published with event_type "insufficient_active_instances"

  Scenario: Ignore registry services that are not in expected_services
    When a fleet poll observes the Service Registry returning the following services
      """
      {
        "beta-service": {
          "inst-1": {
            "status": "down",
            "metadata": {
              "service_name": "beta-service",
              "instance_id": "inst-1",
              "host": "worker-02",
              "pid": 2002,
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
    And no "alert.normalized" event is published for service_name "beta-service"

  Scenario: Expose fleet event types in the subscription catalog
    When I call the RPC get_alert_subscription_catalog on the kontiki-monitor with the following arguments
      """
      {}
      """
    Then the kontiki-monitor RPC call succeeds
    And the kontiki-monitor RPC response includes the event types
      """
      [
        {
          "event_type": "expected_service_missing",
          "label": "Expected service missing",
          "criteria": [
            {
              "key": "service_name",
              "label": "Service name",
              "operators": ["eq", "contains"],
              "value_kind": "string",
              "attribute_key": "service_name"
            }
          ]
        },
        {
          "event_type": "insufficient_active_instances",
          "label": "Insufficient active instances",
          "criteria": [
            {
              "key": "service_name",
              "label": "Service name",
              "operators": ["eq", "contains"],
              "value_kind": "string",
              "attribute_key": "service_name"
            }
          ]
        }
      ]
      """
