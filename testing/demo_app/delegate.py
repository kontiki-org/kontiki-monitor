from kontiki.delegate import ServiceDelegate

DEFAULT_DEGRADED_REASON = "demo degrade requested"


class DemoAppDelegate(ServiceDelegate):
    async def setup(self):
        self._degraded = False
        self._degraded_reason = None

    def set_degraded(self, degraded, reason=None):
        self._degraded = bool(degraded)
        if self._degraded:
            text = str(reason).strip() if reason is not None else ""
            self._degraded_reason = text or DEFAULT_DEGRADED_REASON
        else:
            self._degraded_reason = None
        return self.get_degraded()

    def get_degraded(self):
        out = {"degraded": self._degraded}
        if self._degraded_reason is not None:
            out["reason"] = self._degraded_reason
        return out

    def is_degraded(self):
        if not self._degraded:
            return False
        if self._degraded_reason is not None:
            return True, self._degraded_reason
        return True
