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

# SERVICE is the Poetry script and the image identity.
# VERSION is the tag announced to the registry.
# Both are empty for a local build that starts an explicit command.
ARG SERVICE=
ARG VERSION=
ENV SERVICE=$SERVICE
ENV KONTIKI_MONITOR_VERSION=$VERSION
COPY docker/entrypoint.sh /usr/local/bin/kontiki-entrypoint
RUN chmod +x /usr/local/bin/kontiki-entrypoint \
    && if [ -n "$SERVICE" ] && [ ! -x "/usr/local/bin/$SERVICE" ]; then \
         echo "Unknown service: $SERVICE" >&2; \
         exit 1; \
       fi
ENTRYPOINT ["kontiki-entrypoint"]
