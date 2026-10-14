"""Tests for lib/mic-mute-watch.py. No hidraw, pw-dump or wpctl is touched:
descriptors, sysfs and the Pipewire dump are built in the test."""

# The start of the G733's descriptor: volume keys on report 1, then the
# Telephony page with Phone Mute (0x2f) and Hook Switch on report 8.
G733 = bytes.fromhex(
    "050c0901a101850109e909ea7501950215002501810275069501810375188103c0"
    "050b0901a1018508092f750181060920810675068103c0")
VOLUME_ONLY = bytes.fromhex("050c0901a101850109e909ea750195021500250181 02c0".replace(" ", ""))


def test_the_mute_report_is_found(mic_mute_watch):
    assert mic_mute_watch.mute_report_id(G733) == 8


def test_no_mute_control_is_none(mic_mute_watch):
    assert mic_mute_watch.mute_report_id(VOLUME_ONLY) is None
    assert mic_mute_watch.mute_report_id(b"") is None


def test_a_four_byte_usage_carries_its_page(mic_mute_watch):
    # Usage Page Consumer, then a 4-byte usage 0x000b002f (Telephony, Phone Mute).
    descriptor = bytes.fromhex("050ca1018503" "0b2f000b00" "8106" "c0")
    assert mic_mute_watch.mute_report_id(descriptor) == 3


def hidraw(root, name, descriptor, hid_id):
    device = root / name / "device"
    device.mkdir(parents=True)
    (device / "report_descriptor").write_bytes(descriptor)
    (device / "uevent").write_text(f"DRIVER=hid-generic\nHID_ID={hid_id}\nHID_NAME=x\n")


def test_only_devices_with_a_mute_button_are_watched(mic_mute_watch, tmp_path):
    hidraw(tmp_path, "hidraw4", G733, "0003:0000046D:00000AB5")
    hidraw(tmp_path, "hidraw7", VOLUME_ONLY, "0003:00001532:00000099")
    [button] = mic_mute_watch.find_buttons(tmp_path)
    assert (button.hidraw, button.vendor, button.product, button.report) == \
        ("/dev/hidraw4", 0x046D, 0x0AB5, 8)


def test_the_source_is_the_one_of_the_same_device(mic_mute_watch):
    dump = [
        {"id": 54, "info": {"props": {"device.vendor.id": "0x046d", "device.product.id": "0x0ab5"}}},
        {"id": 56, "info": {"props": {"device.vendor.id": "0x1022", "device.product.id": "0x1487"}}},
        {"id": 64, "info": {"props": {"media.class": "Audio/Source", "device.id": 56}}},
        {"id": 68, "info": {"props": {"media.class": "Audio/Source", "device.id": 54}}},
        {"id": 70, "info": {"props": {"media.class": "Audio/Sink", "device.id": 54}}},
    ]
    assert mic_mute_watch.source_of(0x046D, 0x0AB5, dump) == 68
    assert mic_mute_watch.source_of(0x1234, 0x5678, dump) is None


def test_only_the_mute_report_is_a_press(mic_mute_watch):
    button = mic_mute_watch.MuteButton("/dev/hidraw4", 0x046D, 0x0AB5, 8)
    assert mic_mute_watch.pressed(button, bytes.fromhex("0800"))
    assert not mic_mute_watch.pressed(button, bytes.fromhex("0100000000"))  # volume
    assert not mic_mute_watch.pressed(button, bytes.fromhex("11ff080a0f03"))  # battery reply
    assert not mic_mute_watch.pressed(button, b"")


def test_toggle_mutes_that_source(mic_mute_watch, monkeypatch):
    runs = []
    monkeypatch.setattr(mic_mute_watch, "source_of", lambda v, p: 68)
    monkeypatch.setattr(mic_mute_watch.subprocess, "run", lambda argv, **k: runs.append(argv))
    mic_mute_watch.toggle(mic_mute_watch.MuteButton("/dev/hidraw4", 0x046D, 0x0AB5, 8))
    assert runs == [["wpctl", "set-mute", "68", "toggle"]]
