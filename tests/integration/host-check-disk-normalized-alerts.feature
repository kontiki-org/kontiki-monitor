@host_check @disk
Feature: Detect high disk occupation as normalized alerts
  In order to alert when a host's configured mounts fill up
  As the host-check-service
  I want disk usage polls to become alert.normalized events on edges only

  One deployable instance per host (not the central monitor). V1 is disk occupation
  only: global warning and critical used-percent thresholds, configurable paths.
  A single event_type disk_space_high carries severity warning or critical.
  Open / escalate / recover use a stable alert_id per configured host alias+path;
  attributes.host is that alias, attributes.hostname is the OS hostname at poll time.
  Recover sets resolution=recovered when usage falls below the warning threshold.
  No silences. Missing agent detection is out of scope (disk only).

  The service runs in a Docker container. Configured paths are small tmpfs mounts
  bind-mounted from the host so steps can fill them locally; a real poll reads
  occupation via shutil.disk_usage.

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

  Scenario: Open disk_space_high at warning when occupation reaches the warning threshold
    When a disk usage poll observes the mounts filled as follows
      | path      | percent |
      | /mnt/root | 90      |
      | /mnt/var  | 40      |
    Then an "alert.normalized" event is published with payload
      """
      {
        "source": "host-check-service",
        "category": "kontiki.host",
        "event_type": "disk_space_high",
        "severity": "warning",
        "alert_id": "disk:edge-1:/mnt/root",
        "title": "/mnt/root on edge-1 disk occupation high",
        "attributes": {
          "host": "edge-1",
          "hostname": "box-a7f2",
          "path": "/mnt/root",
          "used_percent": 90,
          "warning_used_percent": 90,
          "critical_used_percent": 95,
          "severity": "warning",
          "resolution": "open"
        }
      }
      """

  Scenario: Do not re-publish while occupation stays in the warning band
    When a disk usage poll observes the mounts filled as follows
      | path      | percent |
      | /mnt/root | 90      |
      | /mnt/var  | 40      |
    Then an "alert.normalized" event is published with payload
      """
      {
        "source": "host-check-service",
        "category": "kontiki.host",
        "event_type": "disk_space_high",
        "severity": "warning",
        "alert_id": "disk:edge-1:/mnt/root",
        "title": "/mnt/root on edge-1 disk occupation high",
        "attributes": {
          "host": "edge-1",
          "hostname": "box-a7f2",
          "path": "/mnt/root",
          "used_percent": 90,
          "warning_used_percent": 90,
          "critical_used_percent": 95,
          "severity": "warning",
          "resolution": "open"
        }
      }
      """
    When a disk usage poll observes the mounts filled as follows
      | path      | percent |
      | /mnt/root | 92      |
      | /mnt/var  | 40      |
    Then no "alert.normalized" event is published

  Scenario: Escalate the same alert to critical when occupation reaches the critical threshold
    When a disk usage poll observes the mounts filled as follows
      | path      | percent |
      | /mnt/root | 90      |
      | /mnt/var  | 40      |
    Then an "alert.normalized" event is published with payload
      """
      {
        "source": "host-check-service",
        "category": "kontiki.host",
        "event_type": "disk_space_high",
        "severity": "warning",
        "alert_id": "disk:edge-1:/mnt/root",
        "title": "/mnt/root on edge-1 disk occupation high",
        "attributes": {
          "host": "edge-1",
          "hostname": "box-a7f2",
          "path": "/mnt/root",
          "used_percent": 90,
          "warning_used_percent": 90,
          "critical_used_percent": 95,
          "severity": "warning",
          "resolution": "open"
        }
      }
      """
    When a disk usage poll observes the mounts filled as follows
      | path      | percent |
      | /mnt/root | 95      |
      | /mnt/var  | 40      |
    Then an "alert.normalized" event is published with payload
      """
      {
        "source": "host-check-service",
        "category": "kontiki.host",
        "event_type": "disk_space_high",
        "severity": "critical",
        "alert_id": "disk:edge-1:/mnt/root",
        "title": "/mnt/root on edge-1 disk occupation high",
        "attributes": {
          "host": "edge-1",
          "hostname": "box-a7f2",
          "path": "/mnt/root",
          "used_percent": 95,
          "warning_used_percent": 90,
          "critical_used_percent": 95,
          "severity": "critical",
          "resolution": "open"
        }
      }
      """

  Scenario: Do not re-publish while occupation stays at or above critical
    When a disk usage poll observes the mounts filled as follows
      | path      | percent |
      | /mnt/root | 95      |
      | /mnt/var  | 40      |
    Then an "alert.normalized" event is published with payload
      """
      {
        "source": "host-check-service",
        "category": "kontiki.host",
        "event_type": "disk_space_high",
        "severity": "critical",
        "alert_id": "disk:edge-1:/mnt/root",
        "title": "/mnt/root on edge-1 disk occupation high",
        "attributes": {
          "host": "edge-1",
          "hostname": "box-a7f2",
          "path": "/mnt/root",
          "used_percent": 95,
          "warning_used_percent": 90,
          "critical_used_percent": 95,
          "severity": "critical",
          "resolution": "open"
        }
      }
      """
    When a disk usage poll observes the mounts filled as follows
      | path      | percent |
      | /mnt/root | 97      |
      | /mnt/var  | 40      |
    Then no "alert.normalized" event is published

  Scenario: De-escalate severity to warning when occupation falls below critical but stays at or above warning
    When a disk usage poll observes the mounts filled as follows
      | path      | percent |
      | /mnt/root | 95      |
      | /mnt/var  | 40      |
    Then an "alert.normalized" event is published with payload
      """
      {
        "source": "host-check-service",
        "category": "kontiki.host",
        "event_type": "disk_space_high",
        "severity": "critical",
        "alert_id": "disk:edge-1:/mnt/root",
        "title": "/mnt/root on edge-1 disk occupation high",
        "attributes": {
          "host": "edge-1",
          "hostname": "box-a7f2",
          "path": "/mnt/root",
          "used_percent": 95,
          "warning_used_percent": 90,
          "critical_used_percent": 95,
          "severity": "critical",
          "resolution": "open"
        }
      }
      """
    When a disk usage poll observes the mounts filled as follows
      | path      | percent |
      | /mnt/root | 91      |
      | /mnt/var  | 40      |
    Then an "alert.normalized" event is published with payload
      """
      {
        "source": "host-check-service",
        "category": "kontiki.host",
        "event_type": "disk_space_high",
        "severity": "warning",
        "alert_id": "disk:edge-1:/mnt/root",
        "title": "/mnt/root on edge-1 disk occupation high",
        "attributes": {
          "host": "edge-1",
          "hostname": "box-a7f2",
          "path": "/mnt/root",
          "used_percent": 91,
          "warning_used_percent": 90,
          "critical_used_percent": 95,
          "severity": "warning",
          "resolution": "open"
        }
      }
      """

  Scenario: Recover disk_space_high when occupation falls below the warning threshold
    When a disk usage poll observes the mounts filled as follows
      | path      | percent |
      | /mnt/root | 90      |
      | /mnt/var  | 40      |
    Then an "alert.normalized" event is published with payload
      """
      {
        "source": "host-check-service",
        "category": "kontiki.host",
        "event_type": "disk_space_high",
        "severity": "warning",
        "alert_id": "disk:edge-1:/mnt/root",
        "title": "/mnt/root on edge-1 disk occupation high",
        "attributes": {
          "host": "edge-1",
          "hostname": "box-a7f2",
          "path": "/mnt/root",
          "used_percent": 90,
          "warning_used_percent": 90,
          "critical_used_percent": 95,
          "severity": "warning",
          "resolution": "open"
        }
      }
      """
    When a disk usage poll observes the mounts filled as follows
      | path      | percent |
      | /mnt/root | 80      |
      | /mnt/var  | 40      |
    Then an "alert.normalized" event is published with payload
      """
      {
        "source": "host-check-service",
        "category": "kontiki.host",
        "event_type": "disk_space_high",
        "severity": "low",
        "alert_id": "disk:edge-1:/mnt/root",
        "title": "/mnt/root on edge-1 disk occupation recovered",
        "attributes": {
          "host": "edge-1",
          "hostname": "box-a7f2",
          "path": "/mnt/root",
          "used_percent": 80,
          "warning_used_percent": 90,
          "critical_used_percent": 95,
          "severity": "low",
          "resolution": "recovered"
        }
      }
      """

  Scenario: Publish no alert when all mounts stay below the warning threshold
    When a disk usage poll observes the mounts filled as follows
      | path      | percent |
      | /mnt/root | 80      |
      | /mnt/var  | 40      |
    Then no "alert.normalized" event is published

  Scenario: Open independent alerts per configured path
    When a disk usage poll observes the mounts filled as follows
      | path      | percent |
      | /mnt/root | 91      |
      | /mnt/var  | 96      |
    Then an "alert.normalized" event is published with payload
      """
      {
        "source": "host-check-service",
        "category": "kontiki.host",
        "event_type": "disk_space_high",
        "severity": "warning",
        "alert_id": "disk:edge-1:/mnt/root",
        "title": "/mnt/root on edge-1 disk occupation high",
        "attributes": {
          "host": "edge-1",
          "hostname": "box-a7f2",
          "path": "/mnt/root",
          "used_percent": 91,
          "warning_used_percent": 90,
          "critical_used_percent": 95,
          "severity": "warning",
          "resolution": "open"
        }
      }
      """
    And an "alert.normalized" event is published with payload
      """
      {
        "source": "host-check-service",
        "category": "kontiki.host",
        "event_type": "disk_space_high",
        "severity": "critical",
        "alert_id": "disk:edge-1:/mnt/var",
        "title": "/mnt/var on edge-1 disk occupation high",
        "attributes": {
          "host": "edge-1",
          "hostname": "box-a7f2",
          "path": "/mnt/var",
          "used_percent": 96,
          "warning_used_percent": 90,
          "critical_used_percent": 95,
          "severity": "critical",
          "resolution": "open"
        }
      }
      """

  Scenario: Open directly at critical when the first observation is already at or above critical
    When a disk usage poll observes the mounts filled as follows
      | path      | percent |
      | /mnt/root | 96      |
      | /mnt/var  | 40      |
    Then an "alert.normalized" event is published with payload
      """
      {
        "source": "host-check-service",
        "category": "kontiki.host",
        "event_type": "disk_space_high",
        "severity": "critical",
        "alert_id": "disk:edge-1:/mnt/root",
        "title": "/mnt/root on edge-1 disk occupation high",
        "attributes": {
          "host": "edge-1",
          "hostname": "box-a7f2",
          "path": "/mnt/root",
          "used_percent": 96,
          "warning_used_percent": 90,
          "critical_used_percent": 95,
          "severity": "critical",
          "resolution": "open"
        }
      }
      """
