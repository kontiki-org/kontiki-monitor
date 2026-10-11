"""Resolve the service release for the publish workflow.

A tag service/x.y.z (GITHUB_REF_NAME) publishes
ghcr.io/<owner>/<service>:<version>. Tags without a slash never start
this workflow.

workflow_dispatch sets INPUT_SERVICE and INPUT_VERSION instead of a tag.
GITHUB_REPOSITORY_OWNER and GITHUB_OUTPUT are set by Actions.
"""

import os
import re
import sys

SERVICE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
VERSION = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+$")


def main():
    service = os.environ.get("INPUT_SERVICE", "")
    version = os.environ.get("INPUT_VERSION", "")
    if not service:
        ref = os.environ["GITHUB_REF_NAME"]
        service, version = ref.split("/", 1)
    if not SERVICE.match(service):
        print(f"Invalid service: {service}", file=sys.stderr)
        sys.exit(1)
    command = f"{service} ="
    with open("pyproject.toml", encoding="utf-8") as handle:
        if not any(line.startswith(command) for line in handle):
            print(f"No {service} command in pyproject.toml", file=sys.stderr)
            sys.exit(1)
    if not VERSION.match(version):
        print(f"Version must be x.y.z, got: {version}", file=sys.stderr)
        sys.exit(1)
    owner = os.environ["GITHUB_REPOSITORY_OWNER"].lower()
    with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as handle:
        handle.write(f"service={service}\n")
        handle.write(f"version={version}\n")
        handle.write(f"image=ghcr.io/{owner}/{service}:{version}\n")


if __name__ == "__main__":
    main()
