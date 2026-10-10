.PHONY: \
	install fmt lint check \
	run-amqp down-amqp \
	integration-test integration-test-tag \
	stack-up stack-down tui \
	demo-app-degrade demo-app-recover demo-app-status demo-app-raise-exception \
	publish-kontiki-monitor publish-host-check

PY ?= poetry run python
SRC = src testing

# Package lives under testing/; set PYTHONPATH so -m works even before editable install.
DEMO_APP_CLI = PYTHONPATH=testing $(PY) -m demo_app.cli

install:
	poetry install

fmt:
	$(PY) -m isort $(SRC)
	$(PY) -m black $(SRC)

lint:
	$(PY) -m flake8 $(SRC)

check: fmt lint

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

# Optional: observe the stack with kontiki-tui (needs stack-up).
# Services default to business group (demo-app). All stack service logs are under
# ./data — set logs.directory in ~/.config/kontiki_tui.yaml if needed.
tui:
	poetry run kontiki-tui

# Host-side RPC against demo-app-service (AMQP on localhost:5672). Needs stack-up.
demo-app-degrade:
	# Heartbeat interval is 5s — wait a few seconds after degrade before checking mail (MailHog :8025).
	$(DEMO_APP_CLI) degrade

demo-app-recover:
	$(DEMO_APP_CLI) recover

demo-app-status:
	$(DEMO_APP_CLI) status

demo-app-raise-exception:
	# Needs a rebuilt demo-app container (new RPC). Triggers registry.exception.recorded.
	$(DEMO_APP_CLI) raise-exception

# Publish one image. One tag per push, so Actions runs one workflow per service.
# make publish-kontiki-monitor VERSION=1.0.0
# make publish-host-check VERSION=1.0.0
define publish_image
	@test -n "$(VERSION)" || { echo "VERSION is required, e.g. make $@ VERSION=1.0.0" >&2; exit 1; }
	@printf '%s' "$(VERSION)" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$$' || { echo "VERSION must be x.y.z, got: $(VERSION)" >&2; exit 1; }
	git tag $(1)/$(VERSION)
	git push origin $(1)/$(VERSION)
endef

publish-kontiki-monitor:
	$(call publish_image,kontiki-monitor)

publish-host-check:
	$(call publish_image,host-check-service)
