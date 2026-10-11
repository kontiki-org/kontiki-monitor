"""Build dist/<service>-<version>.whl.

SERVICE and VERSION name the distribution. The wheel installs that service's
package and exposes its console command.

SOURCE_REF, when set, is the git tag service/version. The tree and
pyproject.toml are read from that tag, so an image already published can
get a matching wheel without moving the tag. Unset means the working tree.
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

SERVICE_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
VERSION_RE = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+$")

PACKAGES = {
    "kontiki-monitor": "kontiki_monitor",
    "host-check-service": "kontiki_host_check",
}

READMES = {
    "kontiki-monitor": "src/kontiki_monitor/README.md",
    "host-check-service": "src/kontiki_host_check/README.md",
}

DESCRIPTIONS = {
    "kontiki-monitor": "Kontiki monitor service.",
    "host-check-service": "Kontiki host check service.",
}


def quote(text):
    escaped = text.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def fail(message):
    print(message, file=sys.stderr)
    sys.exit(1)


def load_poetry(ref):
    if ref:
        raw = subprocess.check_output(
            ["git", "show", f"{ref}:pyproject.toml"], cwd=ROOT
        )
    else:
        raw = (ROOT / "pyproject.toml").read_bytes()
    return tomllib.loads(raw.decode())["tool"]["poetry"]


def pyproject_text(service, version, poetry):
    package = PACKAGES[service]
    entry = poetry["scripts"][service]
    lines = [
        "[build-system]",
        'requires = ["poetry-core"]',
        'build-backend = "poetry.core.masonry.api"',
        "",
        "[tool.poetry]",
        f"name = {quote(service)}",
        f"version = {quote(version)}",
        f"description = {quote(DESCRIPTIONS[service])}",
        "authors = [",
    ]
    for author in poetry["authors"]:
        lines.append(f"    {quote(author)},")
    lines.extend(
        [
            "]",
            'readme = "README.md"',
            'license = "Apache-2.0"',
            f"homepage = {quote(poetry['homepage'])}",
            f"repository = {quote(poetry['repository'])}",
            "packages = [",
            f'    {{ include = {quote(package)}, from = "src" }},',
            "]",
            "classifiers = [",
        ]
    )
    for item in poetry["classifiers"]:
        lines.append(f"    {quote(item)},")
    lines.extend(
        [
            "]",
            "",
            "[tool.poetry.dependencies]",
        ]
    )
    for key, value in poetry["dependencies"].items():
        if not isinstance(value, str):
            fail(f"Unsupported dependency table for {key}.")
        lines.append(f"{key} = {quote(value)}")
    lines.append("")
    lines.append("[tool.poetry.scripts]")
    lines.append(f"{service} = {quote(entry)}")
    lines.append("")
    return "\n".join(lines)


def fill(dest, ref, service):
    package = PACKAGES[service]
    readme_path = READMES[service]
    source = f"src/{package}"
    if ref:
        archive = subprocess.check_output(
            ["git", "archive", ref, source, "LICENSE"], cwd=ROOT
        )
        subprocess.run(["tar", "-x", "-C", str(dest)], input=archive, check=True)
        readme = subprocess.check_output(
            ["git", "show", f"{ref}:{readme_path}"], cwd=ROOT
        )
        (dest / "README.md").write_bytes(readme)
        return
    target = dest / "src" / package
    target.parent.mkdir(parents=True)
    shutil.copytree(
        ROOT / "src" / package,
        target,
        ignore=shutil.ignore_patterns("__pycache__", "*.pyc"),
    )
    shutil.copy(ROOT / "LICENSE", dest / "LICENSE")
    shutil.copy(ROOT / readme_path, dest / "README.md")


def main():
    service = os.environ.get("SERVICE", "")
    version = os.environ.get("VERSION", "")
    ref = os.environ.get("SOURCE_REF", "")
    if not SERVICE_RE.match(service) or service not in READMES:
        fail(f"Unknown service: {service}")
    if not VERSION_RE.match(version):
        fail(f"Version must be x.y.z, got: {version}")
    if ref and ref != f"{service}/{version}":
        fail(f"SOURCE_REF must be {service}/{version}, got: {ref}")
    poetry = load_poetry(ref)
    if service not in poetry["scripts"]:
        fail(f"No {service} command in pyproject.toml")
    dist = ROOT / "dist"
    dist.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        dest = Path(tmp)
        fill(dest, ref, service)
        (dest / "pyproject.toml").write_text(
            pyproject_text(service, version, poetry), encoding="utf-8"
        )
        subprocess.check_call(
            [sys.executable, "-m", "build", "--wheel", "--outdir", str(dist)],
            cwd=dest,
        )


if __name__ == "__main__":
    try:
        import build  # noqa: F401
    except ImportError:
        fail("pip install build")
    main()
