# Build from the parent of both repos (personal/):
#   docker build -f kontiki-monitor/Dockerfile -t kontiki-monitor ..
#
# Layout in the image keeps the Poetry path dep
#   ../boomerang/packages/boomerang-contracts
# resolvable from /workspace/kontiki-monitor.

FROM python:3.12-slim

WORKDIR /workspace/kontiki-monitor

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

RUN pip install --no-cache-dir -U pip

COPY boomerang/packages/boomerang-contracts /workspace/boomerang/packages/boomerang-contracts
COPY kontiki-monitor/pyproject.toml kontiki-monitor/README.md ./
COPY kontiki-monitor/src ./src
COPY kontiki-monitor/config ./config

RUN pip install --no-cache-dir .

CMD ["kontiki-monitor", "--config", "/config/default.yaml"]
