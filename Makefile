.PHONY: install integration-test integration-test-tag stack-up stack-down demo-app-degrade demo-app-recover demo-app-status

BOOMERANG_DIR ?= ../boomerang

install:
	poetry install

# Needs RabbitMQ on localhost (e.g. make stack-up, or Boomerang run-dev-platform-no-registry).
integration-test:
	PYTHONPATH=. poetry run behave tests/integration --stop

integration-test-tag:
	PYTHONPATH=. poetry run behave tests/integration --stop --tags "$(TAG)"

# Full embedded stack (Registry + monitor + Boomerang notifiers). Requires ../boomerang.
stack-up:
	docker compose up -d --build --wait --wait-timeout 180

stack-down:
	docker compose down

demo-app-degrade:
	# Heartbeat interval is 5s — wait a few seconds after degrade before checking mail (MailHog :8025).
	cd $(BOOMERANG_DIR) && poetry run python -m boomerang.testing.demo_app.cli degrade

demo-app-recover:
	cd $(BOOMERANG_DIR) && poetry run python -m boomerang.testing.demo_app.cli recover

demo-app-status:
	cd $(BOOMERANG_DIR) && poetry run python -m boomerang.testing.demo_app.cli status
