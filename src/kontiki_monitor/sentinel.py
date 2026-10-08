"""External sentinel heartbeat: Registry proof, then an empty POST."""

import logging
from datetime import datetime, timedelta, timezone

import aiohttp
from boomerang_contracts.alert.normalized import NormalizedAlert

from kontiki_monitor.names import KONTIKI_MONITOR_SERVICE_NAME

# Fixed scheduler tick so monitors without a sentinel block still start.
# Send spacing is sentinel.interval_seconds.
SENTINEL_HEARTBEAT_TICK_SECONDS = 1
DEFAULT_SENTINEL_INTERVAL_SECONDS = 60
FAILED_POSTS_BEFORE_OPEN = 3

SENTINEL_UNREACHABLE = "sentinel_unreachable"
SENTINEL_ALERT_ID = "sentinel:unreachable"
_POST_TIMEOUT_SECONDS = 10


class SentinelHeartbeat:
    def __init__(
        self, url, token, category, ttl_hours, source=KONTIKI_MONITOR_SERVICE_NAME
    ):
        self.url = url
        self.token = token
        self._category = category
        self._ttl_hours = ttl_hours
        self._source = source
        self._consecutive_failures = 0
        self._open = None

    def observe(self, post_ok):
        if post_ok:
            self._consecutive_failures = 0
            if self._open is None:
                return []
            alert = self._build(resolution="recovered")
            self._open = None
            return [alert]
        self._consecutive_failures += 1
        if (
            self._consecutive_failures < FAILED_POSTS_BEFORE_OPEN
            or self._open is not None
        ):
            return []
        alert = self._build(resolution="open")
        self._open = alert
        return [alert]

    def list_open_alerts(self):
        if self._open is None:
            return []
        return [self._open]

    def _build(self, resolution):
        if resolution == "open":
            severity = "critical"
            title = "sentinel unreachable"
        else:
            severity = "low"
            title = "sentinel recovered"
        occurred_at = datetime.now(timezone.utc)
        expires_at = None
        if self._ttl_hours is not None and self._ttl_hours > 0:
            expires_at = occurred_at + timedelta(hours=self._ttl_hours)
        return NormalizedAlert(
            alert_id=SENTINEL_ALERT_ID,
            source=self._source,
            category=self._category,
            event_type=SENTINEL_UNREACHABLE,
            severity=severity,
            occurred_at=occurred_at,
            title=title,
            body=title,
            areas=[],
            attributes={
                "sentinel_url": self.url,
                "resolution": resolution,
            },
            expires_at=expires_at,
        )


async def send_heartbeat(url, token):
    headers = {"Authorization": "Bearer %s" % token}
    timeout = aiohttp.ClientTimeout(total=_POST_TIMEOUT_SECONDS)
    try:
        async with aiohttp.ClientSession(
            timeout=timeout,
            skip_auto_headers={"User-Agent", "Accept", "Content-Type"},
        ) as session:
            async with session.post(url, data=b"", headers=headers) as response:
                await response.read()
                status = response.status
    except (aiohttp.ClientError, TimeoutError) as exc:
        logging.warning("Sentinel heartbeat POST failed url=%s error=%s", url, exc)
        return False
    if status < 200 or status >= 300:
        logging.warning("Sentinel heartbeat POST failed url=%s status=%s", url, status)
        return False
    logging.info("Sentinel heartbeat POST url=%s status=%s", url, status)
    return True
