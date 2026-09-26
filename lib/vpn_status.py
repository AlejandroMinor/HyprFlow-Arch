#!/usr/bin/env python3
"""VPN indicator for Waybar (continuous: no interval).

Prints the state once, then again only when a network interface appears or
goes away: openconnect and vpnc bring up a tun device when they connect and
drop it when they stop.
"""

import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from waybar_module import WaybarModule, lines  # noqa: E402

CLIENTS = ("openconnect", "vpnc")


def running(name):
    return subprocess.run(["pgrep", "-x", name], capture_output=True).returncode == 0


class VpnStatus(WaybarModule):
    def state(self):
        active = any(running(client) for client in CLIENTS)
        return {"text": "󰒃", "class": "vpn-status-active" if active else "vpn-status-warning"}

    def events(self):
        yield from lines(["ip", "-o", "monitor", "link"])


if __name__ == "__main__":
    VpnStatus().run()
