from kontiki.delegate import ServiceDelegate


class DemoAppDelegate(ServiceDelegate):
    async def setup(self):
        self._degraded = False

    def set_degraded(self, degraded):
        self._degraded = bool(degraded)
        return {"degraded": self._degraded}

    def get_degraded(self):
        return {"degraded": self._degraded}

    def is_degraded(self):
        return self._degraded
