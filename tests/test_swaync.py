"""dotconfig/swaync: the config parses, and every notification that carries a
button has the swaync script that runs it (matched on the app name), so
renaming an app cannot silently break its button."""

import json
import re
import subprocess
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
CONFIG = REPO / "dotconfig" / "swaync" / "config.json"


def scripts_by_app():
    config = json.loads(CONFIG.read_text())
    return {s["app-name"]: s for s in config["scripts"].values()}


def test_the_config_is_valid_json():
    json.loads(CONFIG.read_text())


def test_the_screenshot_button_has_its_script():
    source = (REPO / "lib" / "screenshot.sh").read_text()
    assert "--action open=Open" in source
    app = re.search(r"^hyprflow_name \S+ \S+ \d+ (\S+)$", source, re.M).group(1)
    assert scripts_by_app()[app]["run-on"] == "action"


def test_the_power_saver_button_has_its_script():
    source = (REPO / "lib" / "battery-hub.py").read_text()
    assert '("power", "Power saver")' in source
    app = re.search(r'app="(\w+)", urgency=urgency, icon="battery-low-symbolic", actions=actions',
                    source).group(1)
    script = scripts_by_app()[app]
    assert script["run-on"] == "action" and "power-saver" in script["exec"]


def test_the_style_builds_on_swaync_own():
    css = (REPO / "dotconfig" / "swaync" / "style.css").read_text()
    assert '@import url("file:///etc/xdg/swaync/style.css");' in css


def test_open_finds_the_path_in_the_screenshot_body():
    """The Open script cuts the path out of the toast's body: keep the body
    screenshot.sh sends and that cut in step."""
    source = (REPO / "lib" / "screenshot.sh").read_text()
    body = re.search(r'--action open=Open "(.*)"$', source, re.M).group(1)
    path = "/home/me/Pictures/Screenshots/a b.png"
    body = body.replace('\\"', '"').replace("$out", path)
    command = scripts_by_app()["Screenshot"]["exec"].replace("xdg-open", "echo")
    result = subprocess.run(["sh", "-c", command], env={"SWAYNC_BODY": body, "PATH": "/usr/bin:/bin"},
                            capture_output=True, text=True)
    assert result.stdout.strip() == path
