@kontiki_monitor @alert_silences @alert_silences_persist
Feature: Alert silences persist on disk
  In order to keep maintenance mutes across a kontiki-monitor restart
  As an operator
  I want silenced service names stored in a JSON file that matches list_silences

  Optional config key kontiki-monitor.silences_path (default silences.json in
  the process cwd). Missing file is an empty set. Invalid file is fail fast.

  Background:
    Given the silences file at "[CURRENT_DIR]/silences.json" does not exist
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
        silences_path: "[CURRENT_DIR]/silences.json"
        expected_services:
          alpha-service:
            min_active: 1
      """

  Scenario: Missing silences file is an empty list
    When I call the RPC list_silences on the kontiki-monitor with the following arguments
      """
      {}
      """
    Then the kontiki-monitor RPC call succeeds
    And the kontiki-monitor RPC response is
      """
      []
      """

  Scenario: add_silence writes the silences file
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
    Then the silences file at "[CURRENT_DIR]/silences.json" contains
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

  Scenario: silences survive process restart
    When I call the RPC add_silence on the kontiki-monitor with the following arguments
      """
      {
        "service_name": "alpha-service"
      }
      """
    Then the kontiki-monitor RPC call succeeds
    When the kontiki-monitor process restarts
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
    Then the silences file at "[CURRENT_DIR]/silences.json" contains
      """
      [
        {
          "service_name": "alpha-service"
        }
      ]
      """

  Scenario: clear_silence writes an empty silences file
    When I call the RPC add_silence on the kontiki-monitor with the following arguments
      """
      {
        "service_name": "alpha-service"
      }
      """
    Then the kontiki-monitor RPC call succeeds
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
    Then the silences file at "[CURRENT_DIR]/silences.json" contains
      """
      []
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
