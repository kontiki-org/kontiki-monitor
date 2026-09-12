@kontiki_monitor
Feature: Skip alert.normalized when the Messenger is disconnected
  In order to avoid a Registry exception feedback loop on stack restart
  As the kontiki-monitor and host-check-service
  I want alert.normalized publish attempts that fail with AmqpDisconnectedError
  to be skipped without raising

  Only Kontiki's typed disconnect error is skipped; other publish failures still
  raise. Broker-up publish behaviour stays covered by the existing registry,
  fleet, and disk features.

  The @amqp_disconnected tag programs the harness so Messenger.publish raises
  AmqpDisconnectedError. The When step keeps disconnect visible in the timeline
  (may be a no-op in steps when the tag already applied).

  @amqp_disconnected
  Scenario: Registry lifecycle event does not publish while Messenger is disconnected
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
    When the Messenger is disconnected
    And a "registry.instance.registered" event is published with payload
      """
      {
        "service_name": "email-notifier-service",
        "instance_id": "11111111-2222-3333-4444-555555555555",
        "host": "worker-01",
        "service_version": "1.0.0",
        "timestamp": "2026-07-15T12:00:00Z"
      }
      """
    Then no "alert.normalized" event is published

  @fleet_state @amqp_disconnected
  Scenario: Fleet poll does not publish while Messenger is disconnected
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
        poll_interval_seconds: 8
        expected_services:
          alpha-service:
            min_active: 1
      """
    When the Messenger is disconnected
    And a fleet poll observes the Service Registry returning the following services
      """
      {}
      """
    Then no "alert.normalized" event is published

  @host_check @disk @amqp_disconnected
  Scenario: Disk poll does not publish while Messenger is disconnected
    Given the host-check-service is running with the following configuration
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
    When the Messenger is disconnected
    And a disk usage poll observes the mounts filled as follows
      | path      | percent |
      | /mnt/root | 90      |
      | /mnt/var  | 40      |
    Then no "alert.normalized" event is published
