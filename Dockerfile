FROM python:3.12-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

RUN pip install --no-cache-dir -U pip

COPY pyproject.toml README.md ./
COPY src ./src
COPY testing ./testing
COPY config ./config

RUN pip install --no-cache-dir .

CMD ["kontiki-monitor", "--config", "/config/default.yaml"]
