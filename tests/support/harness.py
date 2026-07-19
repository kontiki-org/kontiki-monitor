"""Local Behave helpers (no dependency on boomerang.testing)."""

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from urllib import error, request

import yaml


def repo_root():
    path = Path(__file__).resolve().parent
    while path != path.parent:
        if (path / "pyproject.toml").is_file():
            return path
        path = path.parent
    raise FileNotFoundError("repo root (pyproject.toml) not found")


def write_temp_config(config):
    fd, config_path = tempfile.mkstemp(suffix=".yaml")
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        yaml.safe_dump(config, handle, sort_keys=False)
    return config_path


def start_kontiki_subprocess(service_entrypoint, config):
    config_path = write_temp_config(config)
    root = repo_root()
    contracts_src = (
        root.parent / "boomerang" / "packages" / "boomerang-contracts" / "src"
    )
    env = os.environ.copy()
    path_parts = [str(root / "src"), str(contracts_src)]
    existing = env.get("PYTHONPATH", "")
    if existing:
        path_parts.append(existing)
    env["PYTHONPATH"] = os.pathsep.join(path_parts)
    proc = subprocess.Popen(
        [
            sys.executable,
            "-m",
            "kontiki.runner.__main__",
            service_entrypoint,
            "--config",
            config_path,
        ],
        cwd=str(root),
        env=env,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
    )
    return proc, config_path


def http_request(method, url, payload=None, headers=None, timeout_seconds=5):
    data = None
    request_headers = {"Accept": "application/json"}
    if headers:
        request_headers.update(headers)
    if payload is not None:
        request_headers["Content-Type"] = "application/json"
        data = json.dumps(payload).encode("utf-8")

    req = request.Request(
        url=url, method=method.upper(), data=data, headers=request_headers
    )
    try:
        with request.urlopen(req, timeout=timeout_seconds) as resp:
            body_raw = resp.read().decode("utf-8") or "{}"
            body = json.loads(body_raw)
            return resp.getcode(), body
    except error.HTTPError as exc:
        body_raw = exc.read().decode("utf-8") or "{}"
        try:
            body = json.loads(body_raw)
        except Exception:
            body = {}
        return exc.code, body


def safe_unlink(path):
    if not path:
        return
    if not os.path.isfile(path):
        return
    try:
        os.unlink(path)
    except OSError:
        pass
