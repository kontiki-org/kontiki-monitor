@host_check @disk
Feature: Detect unavailable configured disk paths as normalized alerts
  In order to alert when a configured mount path cannot be read
  As the host-check-service
  I want failed disk_usage reads to become alert.normalized events on edges only

  Distinct from disk_space_high: event_type disk_path_unavailable (severity critical).
  Stable alert_id per host alias+path. Open while the path is unreadable; recover when
  it becomes readable again. A path in unavailable state does not emit disk_space_high.
  If disk_space_high was open and the path becomes unavailable, recover the occupation
  alert then open disk_path_unavailable. Other configured paths keep being judged.

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

  Scenario: Open disk_path_unavailable when a configured path cannot be read
    When a disk usage poll observes the mounts filled as follows
      | path      | percent |
      | /mnt/root | 40      |
    And a disk usage poll observes path "/mnt/var" as unavailable with error
      """
      No such file or directory
      """
    Then an "alert.normalized" event is published with payload
      """
      {
        "source": "host-check-service",
        "category": "kontiki.host",
        "event_type": "disk_path_unavailable",
        "severity": "critical",
        "alert_id": "disk:edge-1:/mnt/var:unavailable",
        "title": "/mnt/var on edge-1 disk path unavailable",
        "attributes": {
          "host": "edge-1",
          "hostname": "box-a7f2",
          "path": "/mnt/var",
          "error": "No such file or directory",
          "severity": "critical",
          "resolution": "open"
        }
      }
      """

  Scenario: Do not re-publish disk_path_unavailable while the path stays unreadable
    When a disk usage poll observes the mounts filled as follows
      | path      | percent |
      | /mnt/root | 40      |
    And a disk usage poll observes path "/mnt/var" as unavailable with error
      """
      No such file or directory
      """
    Then an "alert.normalized" event is published with payload
      """
      {
        "source": "host-check-service",
        "category": "kontiki.host",
        "event_type": "disk_path_unavailable",
        "severity": "critical",
        "alert_id": "disk:edge-1:/mnt/var:unavailable",
        "title": "/mnt/var on edge-1 disk path unavailable",
        "attributes": {
          "host": "edge-1",
          "hostname": "box-a7f2",
          "path": "/mnt/var",
          "error": "No such file or directory",
          "severity": "critical",
          "resolution": "open"
        }
      }
      """
    When a disk usage poll observes the mounts filled as follows
      | path      | percent |
      | /mnt/root | 40      |
    And a disk usage poll observes path "/mnt/var" as unavailable with error
      """
      Permission denied
      """
    Then no "alert.normalized" event is published

  Scenario: Recover disk_path_unavailable when the path becomes readable again
    When a disk usage poll observes the mounts filled as follows
      | path      | percent |
      | /mnt/root | 40      |
    And a disk usage poll observes path "/mnt/var" as unavailable with error
      """
      No such file or directory
      """
    Then an "alert.normalized" event is published with payload
      """
      {
        "source": "host-check-service",
        "category": "kontiki.host",
        "event_type": "disk_path_unavailable",
        "severity": "critical",
        "alert_id": "disk:edge-1:/mnt/var:unavailable",
        "title": "/mnt/var on edge-1 disk path unavailable",
        "attributes": {
          "host": "edge-1",
          "hostname": "box-a7f2",
          "path": "/mnt/var",
          "error": "No such file or directory",
          "severity": "critical",
          "resolution": "open"
        }
      }
      """
    When a disk usage poll observes the mounts filled as follows
      | path      | percent |
      | /mnt/root | 40      |
      | /mnt/var  | 40      |
    Then an "alert.normalized" event is published with payload
      """
      {
        "source": "host-check-service",
        "category": "kontiki.host",
        "event_type": "disk_path_unavailable",
        "severity": "low",
        "alert_id": "disk:edge-1:/mnt/var:unavailable",
        "title": "/mnt/var on edge-1 disk path recovered",
        "attributes": {
          "host": "edge-1",
          "hostname": "box-a7f2",
          "path": "/mnt/var",
          "error": "",
          "severity": "low",
          "resolution": "recovered"
        }
      }
      """

  Scenario: Recover open disk_space_high then open disk_path_unavailable when the path becomes unreadable
    When a disk usage poll observes the mounts filled as follows
      | path      | percent |
      | /mnt/root | 40      |
      | /mnt/var  | 91      |
    Then an "alert.normalized" event is published with payload
      """
      {
        "source": "host-check-service",
        "category": "kontiki.host",
        "event_type": "disk_space_high",
        "severity": "warning",
        "alert_id": "disk:edge-1:/mnt/var",
        "title": "/mnt/var on edge-1 disk occupation high",
        "attributes": {
          "host": "edge-1",
          "hostname": "box-a7f2",
          "path": "/mnt/var",
          "used_percent": 91,
          "warning_used_percent": 90,
          "critical_used_percent": 95,
          "severity": "warning",
          "resolution": "open"
        }
      }
      """
    When a disk usage poll observes the mounts filled as follows
      | path      | percent |
      | /mnt/root | 40      |
    And a disk usage poll observes path "/mnt/var" as unavailable with error
      """
      No such file or directory
      """
    Then an "alert.normalized" event is published with payload
      """
      {
        "source": "host-check-service",
        "category": "kontiki.host",
        "event_type": "disk_space_high",
        "severity": "low",
        "alert_id": "disk:edge-1:/mnt/var",
        "title": "/mnt/var on edge-1 disk occupation recovered",
        "attributes": {
          "host": "edge-1",
          "hostname": "box-a7f2",
          "path": "/mnt/var",
          "used_percent": 0,
          "warning_used_percent": 90,
          "critical_used_percent": 95,
          "severity": "low",
          "resolution": "recovered"
        }
      }
      """
    And an "alert.normalized" event is published with payload
      """
      {
        "source": "host-check-service",
        "category": "kontiki.host",
        "event_type": "disk_path_unavailable",
        "severity": "critical",
        "alert_id": "disk:edge-1:/mnt/var:unavailable",
        "title": "/mnt/var on edge-1 disk path unavailable",
        "attributes": {
          "host": "edge-1",
          "hostname": "box-a7f2",
          "path": "/mnt/var",
          "error": "No such file or directory",
          "severity": "critical",
          "resolution": "open"
        }
      }
      """

  Scenario: After path recover, open disk_space_high when occupation is already high
    When a disk usage poll observes the mounts filled as follows
      | path      | percent |
      | /mnt/root | 40      |
    And a disk usage poll observes path "/mnt/var" as unavailable with error
      """
      No such file or directory
      """
    Then an "alert.normalized" event is published with payload
      """
      {
        "source": "host-check-service",
        "category": "kontiki.host",
        "event_type": "disk_path_unavailable",
        "severity": "critical",
        "alert_id": "disk:edge-1:/mnt/var:unavailable",
        "title": "/mnt/var on edge-1 disk path unavailable",
        "attributes": {
          "host": "edge-1",
          "hostname": "box-a7f2",
          "path": "/mnt/var",
          "error": "No such file or directory",
          "severity": "critical",
          "resolution": "open"
        }
      }
      """
    When a disk usage poll observes the mounts filled as follows
      | path      | percent |
      | /mnt/root | 40      |
      | /mnt/var  | 96      |
    Then an "alert.normalized" event is published with payload
      """
      {
        "source": "host-check-service",
        "category": "kontiki.host",
        "event_type": "disk_path_unavailable",
        "severity": "low",
        "alert_id": "disk:edge-1:/mnt/var:unavailable",
        "title": "/mnt/var on edge-1 disk path recovered",
        "attributes": {
          "host": "edge-1",
          "hostname": "box-a7f2",
          "path": "/mnt/var",
          "error": "",
          "severity": "low",
          "resolution": "recovered"
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
