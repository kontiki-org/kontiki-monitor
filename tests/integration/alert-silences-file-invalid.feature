@kontiki_monitor @alert_silences @alert_silences_persist
Feature: Invalid silences file prevents start
  In order not to run with a corrupted mute list
  As an operator
  I want kontiki-monitor to fail fast when the silences file cannot be loaded

  Scenario: Corrupt silences file prevents start
    Given the silences file at "[CURRENT_DIR]/silences.json" contains
      """
      { "not": "a list" }
      """
    When I start the kontiki-monitor with the following configuration
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
        silences_path: "[CURRENT_DIR]/silences.json"
        expected_services:
          alpha-service:
            min_active: 1
      """
    Then the kontiki-monitor fails to start
