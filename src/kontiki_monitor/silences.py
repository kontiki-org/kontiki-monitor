"""On/off alert silences keyed by service_name, persisted as JSON."""

import json
import logging
import os
import tempfile

DEFAULT_SILENCES_PATH = "silences.json"


class SilenceStore:
    def __init__(self, path=None):
        resolved = DEFAULT_SILENCES_PATH
        if path is not None:
            text = str(path).strip()
            if text:
                resolved = text
        self._path = resolved
        self._silenced = set()
        self._load()

    def add(self, service_name):
        name = _normalize_service_name(service_name)
        if not name:
            raise ValueError("service_name is required")
        self._silenced.add(name)
        self._save()
        return {"service_name": name}

    def clear(self, service_name):
        name = _normalize_service_name(service_name)
        if not name:
            raise ValueError("service_name is required")
        if name not in self._silenced:
            self._save()
            return {"cleared": False}
        self._silenced.remove(name)
        self._save()
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

    def _load(self):
        if not os.path.isfile(self._path):
            logging.info(
                "Silences file missing path=%s; starting with empty set", self._path
            )
            return
        with open(self._path, encoding="utf-8") as handle:
            raw = json.load(handle)
        self._silenced = {
            _normalize_service_name(entry["service_name"]) for entry in raw
        }
        logging.info(
            "Loaded silences path=%s count=%s", self._path, len(self._silenced)
        )

    def _save(self):
        data = self.list()
        directory = os.path.dirname(os.path.abspath(self._path)) or "."
        os.makedirs(directory, exist_ok=True)
        fd, tmp_path = tempfile.mkstemp(
            prefix=".silences-", suffix=".tmp", dir=directory
        )
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as handle:
                json.dump(data, handle, indent=2)
                handle.write("\n")
            os.replace(tmp_path, self._path)
            tmp_path = None
        finally:
            if tmp_path and os.path.isfile(tmp_path):
                os.unlink(tmp_path)
        logging.info("Wrote silences path=%s count=%s", self._path, len(self._silenced))


def _normalize_service_name(service_name):
    if service_name is None:
        return ""
    return str(service_name).strip()
