@kontiki_monitor @sentinel_heartbeat
Feature: Heartbeat the external sentinel when the supervision chain is up
  In order to keep an external dead-man switch current, and to alert locally when that switch cannot be reached
  As the kontiki-monitor
  I want a heartbeat POST only after Registry get_services returns

  The sentinel block is optional. A heartbeat cycle calls get_services.
  The POST is sent only when that call returns a response.

  The POST body is empty. The Authorization header is "Bearer" plus the configured token.
  A 2xx status is a successful POST. Any other status, or an unreachable sentinel, is a failed POST.

  sentinel_unreachable opens on the third consecutive failed POST and is published once.
  A successful POST before that third failure clears the streak.
  The first successful POST while the alert is open publishes the same alert_id with resolution recovered.
  list_open_alerts returns the open snapshot and drops it after recovery.

  Rule: the sentinel block is configured
    Background:
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
          sentinel:
            url: http://127.0.0.1:18282/watchdogs/prod/heartbeat
            token: secret-token
            interval_seconds: 8
        """

    @sentinel_204
    Scenario: Send the heartbeat POST when get_services returns
      When a sentinel heartbeat cycle runs
      Then the monitor calls the RPC get_services on the Service Registry with the following arguments
        """
        {}
        """
      When the Service Registry RPC response is
        """
        {}
        """
      Then the monitor sends a POST request to "http://127.0.0.1:18282/watchdogs/prod/heartbeat" with the following request
        """
        {
          "headers": {
            "Authorization": "Bearer secret-token"
          },
          "body": ""
        }
        """
      When the sentinel returns status 204 for that POST
      Then no "alert.normalized" event is published with event_type "sentinel_unreachable"

    @sentinel_registry_fail_then_204
    Scenario: Skip the POST when get_services fails and send it on the next successful cycle
      When a sentinel heartbeat cycle runs
      Then the monitor calls the RPC get_services on the Service Registry with the following arguments
        """
        {}
        """
      When the Service Registry RPC call fails
      Then the monitor sends no POST request to "http://127.0.0.1:18282/watchdogs/prod/heartbeat"
      Then no "alert.normalized" event is published with event_type "sentinel_unreachable"
      When a sentinel heartbeat cycle runs
      Then the monitor calls the RPC get_services on the Service Registry with the following arguments
        """
        {}
        """
      When the Service Registry RPC response is
        """
        {}
        """
      Then the monitor sends a POST request to "http://127.0.0.1:18282/watchdogs/prod/heartbeat" with the following request
        """
        {
          "headers": {
            "Authorization": "Bearer secret-token"
          },
          "body": ""
        }
        """
      When the sentinel returns status 204 for that POST
      Then no "alert.normalized" event is published with event_type "sentinel_unreachable"

    @sentinel_third_failure_then_recover
    Scenario: Open sentinel_unreachable on the third consecutive failed POST and recover on success
      When a sentinel heartbeat cycle runs
      Then the monitor calls the RPC get_services on the Service Registry with the following arguments
        """
        {}
        """
      When the Service Registry RPC response is
        """
        {}
        """
      Then the monitor sends a POST request to "http://127.0.0.1:18282/watchdogs/prod/heartbeat" with the following request
        """
        {
          "headers": {
            "Authorization": "Bearer secret-token"
          },
          "body": ""
        }
        """
      When the sentinel is unreachable for that POST
      Then no "alert.normalized" event is published with event_type "sentinel_unreachable"
      When a sentinel heartbeat cycle runs
      Then the monitor calls the RPC get_services on the Service Registry with the following arguments
        """
        {}
        """
      When the Service Registry RPC response is
        """
        {}
        """
      Then the monitor sends a POST request to "http://127.0.0.1:18282/watchdogs/prod/heartbeat" with the following request
        """
        {
          "headers": {
            "Authorization": "Bearer secret-token"
          },
          "body": ""
        }
        """
      When the sentinel returns status 503 for that POST
      Then no "alert.normalized" event is published with event_type "sentinel_unreachable"
      When a sentinel heartbeat cycle runs
      Then the monitor calls the RPC get_services on the Service Registry with the following arguments
        """
        {}
        """
      When the Service Registry RPC response is
        """
        {}
        """
      Then the monitor sends a POST request to "http://127.0.0.1:18282/watchdogs/prod/heartbeat" with the following request
        """
        {
          "headers": {
            "Authorization": "Bearer secret-token"
          },
          "body": ""
        }
        """
      When the sentinel is unreachable for that POST
      Then an "alert.normalized" event is published with payload
        """
        {
          "schema_version": "1.0",
          "alert_id": "sentinel:unreachable",
          "source": "kontiki-monitor",
          "category": "kontiki.registry",
          "event_type": "sentinel_unreachable",
          "severity": "critical",
          "occurred_at": "*",
          "title": "sentinel unreachable",
          "body": "sentinel unreachable",
          "areas": [],
          "attributes": {
            "url": "http://127.0.0.1:18282/watchdogs/prod/heartbeat",
            "resolution": "open"
          },
          "expires_at": null
        }
        """
      When a sentinel heartbeat cycle runs
      Then the monitor calls the RPC get_services on the Service Registry with the following arguments
        """
        {}
        """
      When the Service Registry RPC response is
        """
        {}
        """
      Then the monitor sends a POST request to "http://127.0.0.1:18282/watchdogs/prod/heartbeat" with the following request
        """
        {
          "headers": {
            "Authorization": "Bearer secret-token"
          },
          "body": ""
        }
        """
      When the sentinel returns status 503 for that POST
      Then no "alert.normalized" event is published with event_type "sentinel_unreachable"
      When I call the RPC list_open_alerts on the kontiki-monitor with the following arguments
        """
        {}
        """
      Then the kontiki-monitor RPC call succeeds
      And the kontiki-monitor RPC response is
        """
        [
          {
            "schema_version": "1.0",
            "alert_id": "sentinel:unreachable",
            "source": "kontiki-monitor",
            "category": "kontiki.registry",
            "event_type": "sentinel_unreachable",
            "severity": "critical",
            "occurred_at": "*",
            "title": "sentinel unreachable",
            "body": "sentinel unreachable",
            "areas": [],
            "attributes": {
              "url": "http://127.0.0.1:18282/watchdogs/prod/heartbeat",
              "resolution": "open"
            },
            "expires_at": null
          }
        ]
        """
      When a sentinel heartbeat cycle runs
      Then the monitor calls the RPC get_services on the Service Registry with the following arguments
        """
        {}
        """
      When the Service Registry RPC response is
        """
        {}
        """
      Then the monitor sends a POST request to "http://127.0.0.1:18282/watchdogs/prod/heartbeat" with the following request
        """
        {
          "headers": {
            "Authorization": "Bearer secret-token"
          },
          "body": ""
        }
        """
      When the sentinel returns status 204 for that POST
      Then an "alert.normalized" event is published with payload
        """
        {
          "schema_version": "1.0",
          "alert_id": "sentinel:unreachable",
          "source": "kontiki-monitor",
          "category": "kontiki.registry",
          "event_type": "sentinel_unreachable",
          "severity": "low",
          "occurred_at": "*",
          "title": "sentinel recovered",
          "body": "sentinel recovered",
          "areas": [],
          "attributes": {
            "url": "http://127.0.0.1:18282/watchdogs/prod/heartbeat",
            "resolution": "recovered"
          },
          "expires_at": null
        }
        """
      When I call the RPC list_open_alerts on the kontiki-monitor with the following arguments
        """
        {}
        """
      Then the kontiki-monitor RPC call succeeds
      And the kontiki-monitor RPC response is
        """
        []
        """

    @sentinel_success_clears_streak
    Scenario: A successful POST before the third failure clears the streak
      When a sentinel heartbeat cycle runs
      Then the monitor calls the RPC get_services on the Service Registry with the following arguments
        """
        {}
        """
      When the Service Registry RPC response is
        """
        {}
        """
      Then the monitor sends a POST request to "http://127.0.0.1:18282/watchdogs/prod/heartbeat" with the following request
        """
        {
          "headers": {
            "Authorization": "Bearer secret-token"
          },
          "body": ""
        }
        """
      When the sentinel is unreachable for that POST
      Then no "alert.normalized" event is published with event_type "sentinel_unreachable"
      When a sentinel heartbeat cycle runs
      Then the monitor calls the RPC get_services on the Service Registry with the following arguments
        """
        {}
        """
      When the Service Registry RPC response is
        """
        {}
        """
      Then the monitor sends a POST request to "http://127.0.0.1:18282/watchdogs/prod/heartbeat" with the following request
        """
        {
          "headers": {
            "Authorization": "Bearer secret-token"
          },
          "body": ""
        }
        """
      When the sentinel is unreachable for that POST
      Then no "alert.normalized" event is published with event_type "sentinel_unreachable"
      When a sentinel heartbeat cycle runs
      Then the monitor calls the RPC get_services on the Service Registry with the following arguments
        """
        {}
        """
      When the Service Registry RPC response is
        """
        {}
        """
      Then the monitor sends a POST request to "http://127.0.0.1:18282/watchdogs/prod/heartbeat" with the following request
        """
        {
          "headers": {
            "Authorization": "Bearer secret-token"
          },
          "body": ""
        }
        """
      When the sentinel returns status 204 for that POST
      Then no "alert.normalized" event is published with event_type "sentinel_unreachable"
      When a sentinel heartbeat cycle runs
      Then the monitor calls the RPC get_services on the Service Registry with the following arguments
        """
        {}
        """
      When the Service Registry RPC response is
        """
        {}
        """
      Then the monitor sends a POST request to "http://127.0.0.1:18282/watchdogs/prod/heartbeat" with the following request
        """
        {
          "headers": {
            "Authorization": "Bearer secret-token"
          },
          "body": ""
        }
        """
      When the sentinel is unreachable for that POST
      Then no "alert.normalized" event is published with event_type "sentinel_unreachable"

  Rule: the sentinel block is absent
    Background:
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

    Scenario: Send no heartbeat POST when the sentinel block is absent
      When a sentinel heartbeat cycle runs
      Then the monitor sends no sentinel heartbeat POST
      Then no "alert.normalized" event is published with event_type "sentinel_unreachable"
