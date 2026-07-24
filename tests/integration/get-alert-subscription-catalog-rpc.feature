@kontiki_monitor
Feature: Expose Kontiki Registry subscription catalog via RPC
  In order to configure subscriptions from the platform catalog
  As the kontiki-monitor
  I want to return registry alert criteria metadata over RPC

  Kontiki 1.1.0 publishes registry.instance.* and registry.exception.recorded on the bus.
  This connector maps them to NormalizedAlert event types used in subscriptions.
  instance_id is included in alert attributes for correlation but is not a subscription criterion (ephemeral per process start).

  Scenario: Return subscription catalog for Kontiki Registry alerts
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
    When I call the RPC get_alert_subscription_catalog on the kontiki-monitor with the following arguments
      """
      {}
      """
    Then the kontiki-monitor RPC call succeeds
    And the kontiki-monitor RPC response is
      """
      {
        "source_id": "kontiki-monitor",
        "categories": [
          {
            "category": "kontiki.registry",
            "label": "Kontiki Registry",
            "event_types": [
              {
                "event_type": "instance_registered",
                "label": "Instance registered",
                "criteria": [
                  {
                    "key": "service_name",
                    "label": "Service name",
                    "operators": ["eq", "contains"],
                    "value_kind": "string",
                    "attribute_key": "service_name"
                  },
                  {
                    "key": "host",
                    "label": "Host",
                    "operators": ["eq", "contains"],
                    "value_kind": "string",
                    "attribute_key": "host"
                  },
                  {
                    "key": "version",
                    "label": "Version",
                    "operators": ["eq", "contains"],
                    "value_kind": "string",
                    "attribute_key": "version"
                  }
                ]
              },
              {
                "event_type": "instance_unregistered",
                "label": "Instance unregistered",
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
                "event_type": "instance_state_changed",
                "label": "Instance state changed",
                "criteria": [
                  {
                    "key": "service_name",
                    "label": "Service name",
                    "operators": ["eq", "contains"],
                    "value_kind": "string",
                    "attribute_key": "service_name"
                  },
                  {
                    "key": "previous_state",
                    "label": "Previous state",
                    "operators": ["eq"],
                    "value_kind": "string",
                    "attribute_key": "previous_state"
                  },
                  {
                    "key": "new_state",
                    "label": "New state",
                    "operators": ["eq"],
                    "value_kind": "string",
                    "attribute_key": "new_state"
                  },
                  {
                    "key": "reason",
                    "label": "Reason",
                    "operators": ["eq", "contains"],
                    "value_kind": "string",
                    "attribute_key": "reason"
                  }
                ]
              },
              {
                "event_type": "exception_recorded",
                "label": "Exception recorded",
                "criteria": [
                  {
                    "key": "service_name",
                    "label": "Service name",
                    "operators": ["eq", "contains"],
                    "value_kind": "string",
                    "attribute_key": "service_name"
                  },
                  {
                    "key": "exception_type",
                    "label": "Exception type",
                    "operators": ["eq", "contains"],
                    "value_kind": "string",
                    "attribute_key": "exception_type"
                  }
                ]
              },
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
          }
        ]
      }
      """
