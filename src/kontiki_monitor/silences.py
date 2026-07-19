"""In-memory on/off alert silences keyed by service_name."""


class SilenceStore:
    def __init__(self):
        self._silenced = set()

    def add(self, service_name):
        name = _normalize_service_name(service_name)
        if not name:
            raise ValueError("service_name is required")
        self._silenced.add(name)
        return {"service_name": name}

    def clear(self, service_name):
        name = _normalize_service_name(service_name)
        if not name:
            raise ValueError("service_name is required")
        if name not in self._silenced:
            return {"cleared": False}
        self._silenced.remove(name)
        return {"cleared": True}

    def list(self):
        return [{"service_name": name} for name in sorted(self._silenced)]

    def is_silenced(self, service_name):
        name = _normalize_service_name(service_name)
        if not name:
            return False
        return name in self._silenced

    def names(self):
        return set(self._silenced)


def _normalize_service_name(service_name):
    if service_name is None:
        return ""
    return str(service_name).strip()
