"""Bounded tmpfs mounts + host-check Docker container for disk Behave tests."""

import os
import shutil
import subprocess
import tempfile
import uuid
from pathlib import Path

from tests.support.harness import repo_root, write_temp_config

ALPINE_IMAGE = "alpine:3.20"
HOST_CHECK_IMAGE = "kontiki-monitor:local"
TMPFS_SIZE = "32m"
CONTAINER_HOSTNAME = "box-a7f2"
FIXTURE_MOUNT = "/fixture"


_image_ready = False


def ensure_host_check_image():
    global _image_ready
    if _image_ready:
        return
    root = repo_root()
    subprocess.check_call(
        [
            "docker",
            "build",
            "-t",
            HOST_CHECK_IMAGE,
            "-f",
            str(root / "Dockerfile"),
            str(root),
        ]
    )
    _image_ready = True


def _mount_tmpfs(host_dir):
    os.makedirs(host_dir, exist_ok=True)
    parent = str(Path(host_dir).parent)
    name = Path(host_dir).name
    subprocess.check_call(
        [
            "docker",
            "run",
            "--rm",
            "--privileged",
            "--mount",
            "type=bind,source=%s,target=/shared,bind-propagation=rshared" % parent,
            ALPINE_IMAGE,
            "sh",
            "-c",
            "mountpoint -q /shared/%s || mount -t tmpfs -o size=%s tmpfs /shared/%s"
            % (name, TMPFS_SIZE, name),
        ]
    )


def _unmount_tmpfs(host_dir):
    if not os.path.isdir(host_dir):
        return
    parent = str(Path(host_dir).parent)
    name = Path(host_dir).name
    subprocess.call(
        [
            "docker",
            "run",
            "--rm",
            "--privileged",
            "--mount",
            "type=bind,source=%s,target=/shared,bind-propagation=rshared" % parent,
            ALPINE_IMAGE,
            "sh",
            "-c",
            "mountpoint -q /shared/%s && umount /shared/%s || true" % (name, name),
        ]
    )


def set_mount_used_percent(host_dir, percent):
    percent = int(percent)
    for name in os.listdir(host_dir):
        path = os.path.join(host_dir, name)
        if os.path.isfile(path):
            os.unlink(path)
    usage = shutil.disk_usage(host_dir)
    target = usage.total * percent // 100
    need = target - usage.used
    if need > 0:
        fill_path = os.path.join(host_dir, "fill.bin")
        subprocess.check_call(["fallocate", "-l", str(need), fill_path])
    usage = shutil.disk_usage(host_dir)
    if usage.total <= 0:
        return 0
    return int((usage.used * 100) / usage.total)


def container_used_percent(fixture, container_path):
    name = fixture["container_name"]
    script = (
        "import shutil; u=shutil.disk_usage(%r); "
        "print(0 if u.total<=0 else int((u.used*100)/u.total))"
    ) % container_path
    out = subprocess.check_output(
        ["docker", "exec", name, "python", "-c", script],
        text=True,
    ).strip()
    return int(out)


def fill_mount(fixture, container_path, percent):
    percent = int(percent)
    unavailable = fixture.get("unavailable_paths") or set()
    if container_path in unavailable:
        remount_path_in_container(fixture, container_path)
    host_dir = fixture["host_by_container"][container_path]
    # Bind mounts can report slightly lower usage inside the container than on the
    # host; top up until the container's shutil.disk_usage matches the target.
    for _ in range(8):
        set_mount_used_percent(host_dir, percent)
        actual = container_used_percent(fixture, container_path)
        if actual >= percent:
            return actual
        usage = shutil.disk_usage(host_dir)
        bump = max(usage.total // 100, 4096)
        fill_path = os.path.join(host_dir, "fill-bump-%s.bin" % _)
        subprocess.check_call(["fallocate", "-l", str(bump), fill_path])
    actual = container_used_percent(fixture, container_path)
    return actual


def _fixture_rel(fixture, host_dir):
    return os.path.relpath(host_dir, fixture["work_dir"])


def remount_path_in_container(fixture, container_path):
    name = fixture["container_name"]
    host_dir = fixture["host_by_container"][container_path]
    os.makedirs(host_dir, exist_ok=True)
    _mount_tmpfs(host_dir)
    rel = _fixture_rel(fixture, host_dir)
    subprocess.check_call(
        [
            "docker",
            "exec",
            "--privileged",
            name,
            "sh",
            "-c",
            "umount '%s' 2>/dev/null || true; mkdir -p '%s' && mount --bind '%s/%s' '%s'"
            % (container_path, container_path, FIXTURE_MOUNT, rel, container_path),
        ]
    )
    unavailable = fixture.setdefault("unavailable_paths", set())
    unavailable.discard(container_path)


def make_path_unavailable(fixture, container_path):
    name = fixture["container_name"]
    host_dir = fixture["host_by_container"][container_path]
    subprocess.call(
        [
            "docker",
            "exec",
            "--privileged",
            name,
            "sh",
            "-c",
            "umount '%s' 2>/dev/null || true; rm -rf '%s'" % (container_path, container_path),
        ]
    )
    _unmount_tmpfs(host_dir)
    fixture.setdefault("unavailable_paths", set()).add(container_path)


def start_host_check_disk_container(config):
    ensure_host_check_image()
    paths = list(((config.get("host-check") or {}).get("paths")) or [])
    if not paths:
        raise RuntimeError("host-check.paths required for disk fixture container")

    work = tempfile.mkdtemp(prefix="km-disk-")
    host_by_container = {}
    for index, container_path in enumerate(paths):
        host_dir = os.path.join(work, "mnt-%s" % index)
        _mount_tmpfs(host_dir)
        host_by_container[container_path] = host_dir

    config_path = write_temp_config(config)
    name = "km-host-check-%s" % uuid.uuid4().hex[:8]
    cmd = [
        "docker",
        "run",
        "-d",
        "--rm",
        "--name",
        name,
        "--hostname",
        CONTAINER_HOSTNAME,
        "--network",
        "host",
        "--privileged",
        "-v",
        "%s:/config/service.yaml:ro" % config_path,
        "-v",
        "%s:%s:rshared" % (work, FIXTURE_MOUNT),
    ]
    for container_path, host_dir in host_by_container.items():
        cmd.extend(["-v", "%s:%s" % (host_dir, container_path)])
    cmd.extend(
        [HOST_CHECK_IMAGE, "host-check-service", "--config", "/config/service.yaml"]
    )
    subprocess.check_call(cmd)

    return {
        "container_name": name,
        "config_path": config_path,
        "work_dir": work,
        "host_by_container": host_by_container,
        "unavailable_paths": set(),
    }


def stop_host_check_disk_container(fixture):
    if not fixture:
        return
    name = fixture.get("container_name")
    if name:
        subprocess.call(["docker", "rm", "-f", name], stdout=subprocess.DEVNULL)
    for host_dir in (fixture.get("host_by_container") or {}).values():
        _unmount_tmpfs(host_dir)
    work = fixture.get("work_dir")
    if work and os.path.isdir(work):
        shutil.rmtree(work, ignore_errors=True)
    config_path = fixture.get("config_path")
    if config_path and os.path.isfile(config_path):
        try:
            os.unlink(config_path)
        except OSError:
            pass
