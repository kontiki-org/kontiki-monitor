@host_check @disk @list_open_alerts
Feature: List currently open disk alerts on host-check-service
  In order to see disk conditions that are still true on this host
  As an operator querying host-check-service
  I want list_open_alerts to return the open NormalizedAlert snapshots

  RPC list_open_alerts {} returns a JSON list sorted by alert_id.
  Each item is a full NormalizedAlert with attributes.resolution open,
  the same object as the open alert.normalized edge. The RPC does not publish.
  This instance lists only its own disk opens. Monitor silences do not apply.

  Background:
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
        poll_interval_seconds: 8
        warning_used_percent: 90
        critical_used_percent: 95
        paths:
          - /mnt/root
          - /mnt/var
      """

  Scenario: list_open_alerts is empty when occupation is below warning
    When a disk usage poll observes the mounts filled as follows
      | path      | percent |
      | /mnt/root | 40      |
      | /mnt/var  | 40      |
    Then no "alert.normalized" event is published
    When I call the RPC list_open_alerts on the host-check-service with the following arguments
      """
      {}
      """
    Then the host-check-service RPC call succeeds
    And the host-check-service RPC response is
      """
      []
      """

  Scenario: Open disk_space_high appears in list_open_alerts
    When a disk usage poll observes the mounts filled as follows
      | path      | percent |
      | /mnt/root | 90      |
      | /mnt/var  | 40      |
    Then an "alert.normalized" event is published with payload
      """
      {
        "schema_version": "1.0",
        "alert_id": "disk:edge-1:/mnt/root",
        "source": "host-check-service",
        "category": "kontiki.host",
        "event_type": "disk_space_high",
        "severity": "warning",
        "occurred_at": "*",
        "title": "/mnt/root on edge-1 disk occupation high",
        "body": "/mnt/root on edge-1 disk occupation high",
        "areas": [],
        "attributes": {
          "host": "edge-1",
          "hostname": "box-a7f2",
          "path": "/mnt/root",
          "used_percent": 90,
          "warning_used_percent": 90,
          "critical_used_percent": 95,
          "severity": "warning",
          "resolution": "open"
        },
        "expires_at": null
      }
      """
    When I call the RPC list_open_alerts on the host-check-service with the following arguments
      """
      {}
      """
    Then the host-check-service RPC call succeeds
    And the host-check-service RPC response is
      """
      [
        {
          "schema_version": "1.0",
          "alert_id": "disk:edge-1:/mnt/root",
          "source": "host-check-service",
          "category": "kontiki.host",
          "event_type": "disk_space_high",
          "severity": "warning",
          "occurred_at": "*",
          "title": "/mnt/root on edge-1 disk occupation high",
          "body": "/mnt/root on edge-1 disk occupation high",
          "areas": [],
          "attributes": {
            "host": "edge-1",
            "hostname": "box-a7f2",
            "path": "/mnt/root",
            "used_percent": 90,
            "warning_used_percent": 90,
            "critical_used_percent": 95,
            "severity": "warning",
            "resolution": "open"
          },
          "expires_at": null
        }
      ]
      """

  Scenario: Recovered disk_space_high is gone from list_open_alerts
    When a disk usage poll observes the mounts filled as follows
      | path      | percent |
      | /mnt/root | 90      |
      | /mnt/var  | 40      |
    Then an "alert.normalized" event is published with payload
      """
      {
        "schema_version": "1.0",
        "alert_id": "disk:edge-1:/mnt/root",
        "source": "host-check-service",
        "category": "kontiki.host",
        "event_type": "disk_space_high",
        "severity": "warning",
        "occurred_at": "*",
        "title": "/mnt/root on edge-1 disk occupation high",
        "body": "/mnt/root on edge-1 disk occupation high",
        "areas": [],
        "attributes": {
          "host": "edge-1",
          "hostname": "box-a7f2",
          "path": "/mnt/root",
          "used_percent": 90,
          "warning_used_percent": 90,
          "critical_used_percent": 95,
          "severity": "warning",
          "resolution": "open"
        },
        "expires_at": null
      }
      """
    When a disk usage poll observes the mounts filled as follows
      | path      | percent |
      | /mnt/root | 80      |
      | /mnt/var  | 40      |
    Then an "alert.normalized" event is published with payload
      """
      {
        "schema_version": "1.0",
        "alert_id": "disk:edge-1:/mnt/root",
        "source": "host-check-service",
        "category": "kontiki.host",
        "event_type": "disk_space_high",
        "severity": "low",
        "occurred_at": "*",
        "title": "/mnt/root on edge-1 disk occupation recovered",
        "body": "/mnt/root on edge-1 disk occupation recovered",
        "areas": [],
        "attributes": {
          "host": "edge-1",
          "hostname": "box-a7f2",
          "path": "/mnt/root",
          "used_percent": 80,
          "warning_used_percent": 90,
          "critical_used_percent": 95,
          "severity": "low",
          "resolution": "recovered"
        },
        "expires_at": null
      }
      """
    When I call the RPC list_open_alerts on the host-check-service with the following arguments
      """
      {}
      """
    Then the host-check-service RPC call succeeds
    And the host-check-service RPC response is
      """
      []
      """
