"""Harness entry: kontiki runner with Messenger.publish raising AmqpDisconnectedError."""

import sys

from tests.support.amqp_disconnected import patch_messenger_publish_disconnected

patch_messenger_publish_disconnected()

from kontiki.runner.__main__ import main  # noqa: E402

if __name__ == "__main__":
    # Drop this module from argv so kontiki.runner sees service_class --config …
    sys.argv = [sys.argv[0]] + sys.argv[1:]
    main()
