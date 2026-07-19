.PHONY: \
	install run-amqp down-amqp \
	integration-test integration-test-tag \
	stack-up stack-down \
	demo-app-degrade demo-app-recover demo-app-status

BOOMERANG_IMAGE ?= kontiki-monitor-boomerang:local
DEMO_APP_CLI = docker run --rm --network host $(BOOMERANG_IMAGE) \
	python -m boomerang.testing.demo_app.cli

install:
	poetry install

# RabbitMQ only — Behave owns ServiceRegistryMock (do not start a real Registry).
run-amqp:
	docker compose up -d --wait --wait-timeout 180 rabbitmq

down-amqp:
	docker compose stop rabbitmq 2>/dev/null || true

# Needs RabbitMQ on localhost without a real ServiceRegistry (e.g. make run-amqp).
# Boomerang `make run-dev-platform` starts a real Registry and conflicts with the mock.
integration-test:
	PYTHONPATH=. poetry run behave tests/integration --stop

integration-test-tag:
	PYTHONPATH=. poetry run behave tests/integration --stop --tags "$(TAG)"

# Full embedded stack (Registry + monitor + Boomerang notifiers from PyPI images).
stack-up:
	docker compose up -d --build --wait --wait-timeout 180

stack-down:
	docker compose down

# Host-side RPC against demo-app-service (AMQP on localhost:5672). Needs stack-up
# (or a prior build of $(BOOMERANG_IMAGE)).
demo-app-degrade:
	# Heartbeat interval is 5s — wait a few seconds after degrade before checking mail (MailHog :8025).
	$(DEMO_APP_CLI) degrade

demo-app-recover:
	$(DEMO_APP_CLI) recover

demo-app-status:
	$(DEMO_APP_CLI) status
