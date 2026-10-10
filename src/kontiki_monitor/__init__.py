import os
from importlib.metadata import version

image_version = os.environ.get("KONTIKI_MONITOR_VERSION", "")
__version__ = image_version or version("kontiki-monitor")
