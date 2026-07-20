@host_check
Feature: Expose host disk subscription catalog via RPC
  In order to configure subscriptions from the platform catalog
  As the host-check-service
  I want to return disk occupation alert criteria metadata over RPC

  V1 publishes a single NormalizedAlert event_type disk_space_high with severity
  warning or critical. Subscriptions can filter on host (config alias), path, and
  severity. OS hostname is carried in alert attributes for ops correlation but is
  not a subscription criterion (may change across rebuilds).

  Scenario: Return subscription catalog for host disk alerts
    Given the host-check-service is running with the following configuration
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
            filename: /tmp/host-check-service.log
            level: INFO
        root:
          level: DEBUG
          handlers:
            - file
      host-check:
        host: "edge-1"
        category: "kontiki.host"
        poll_interval_seconds: 30
        warning_used_percent: 90
        critical_used_percent: 95
        paths:
          - /
      """
    When I call the RPC get_alert_subscription_catalog on the host-check-service with the following arguments
      """
      {}
      """
    Then the host-check-service RPC call succeeds
    And the host-check-service RPC response is
      """
      {
        "source_id": "host-check-service",
        "categories": [
          {
            "category": "kontiki.host",
            "label": "Kontiki Host",
            "event_types": [
              {
                "event_type": "disk_space_high",
                "label": "Disk occupation high",
                "criteria": [
                  {
                    "key": "host",
                    "label": "Host",
                    "operators": ["eq", "contains"],
                    "value_kind": "string",
                    "attribute_key": "host"
                  },
                  {
                    "key": "path",
                    "label": "Mount path",
                    "operators": ["eq", "contains"],
                    "value_kind": "string",
                    "attribute_key": "path"
                  },
                  {
                    "key": "severity",
                    "label": "Severity",
                    "operators": ["eq"],
                    "value_kind": "string",
                    "attribute_key": "severity"
                  }
                ]
              }
            ]
          }
        ]
      }
      """
