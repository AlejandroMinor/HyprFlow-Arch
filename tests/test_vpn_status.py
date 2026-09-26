"""Tests for lib/vpn_status.py: pgrep and ip monitor are faked."""

import pytest


@pytest.mark.parametrize("running, expected", [
    ({"openconnect"}, "vpn-status-active"),
    ({"vpnc"}, "vpn-status-active"),
    (set(), "vpn-status-warning"),
])
def test_state_follows_the_vpn_clients(vpn, monkeypatch, running, expected):
    monkeypatch.setattr(vpn, "running", lambda name: name in running)
    state = vpn.VpnStatus().state()
    assert state == {"text": "󰒃", "class": expected}


def test_every_link_event_counts(vpn, monkeypatch):
    monkeypatch.setattr(vpn, "lines", lambda cmd: iter(["1: lo: ...\n", "5: tun0: ...\n"]))
    assert len(list(vpn.VpnStatus().events())) == 2
