"""bar.json, the Quickshell bar's layout: every name resolves to a module
file, as bar/ModuleLoader.qml resolves it, and the scripts it runs exist."""

import json
import re
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
BAR = REPO / "dotconfig" / "quickshell" / "hyprflow" / "bar"


def parse(path):
    """As Bars.qml parse(): // comments dropped, except inside strings."""
    text, out, quoted, i = path.read_text(), [], False, 0
    while i < len(text):
        c = text[i]
        if quoted:
            out.append(c)
            if c == "\\":
                i += 1
                out.append(text[i])
            elif c == '"':
                quoted = False
        elif c == '"':
            quoted = True
            out.append(c)
        elif text.startswith("//", i):
            while i + 1 < len(text) and text[i + 1] != "\n":
                i += 1
        else:
            out.append(c)
        i += 1
    return json.loads("".join(out))


def config():
    return parse(BAR / "bar.json")


def module_file(name, modules):
    """ModuleLoader: the settings' type, or else the name; kebab-case to
    PascalCase (system-tools → SystemTools.qml)."""
    kind = modules.get(name, {}).get("type", name)
    return BAR / "modules" / ("".join(w[:1].upper() + w[1:] for w in kind.split("-")) + ".qml")


def every_name(cfg):
    for layout in cfg["bars"].values():
        for side in ("left", "center", "right"):
            yield from layout.get(side, [])
    for settings in cfg["modules"].values():
        yield from settings.get("modules", [])   # a drawer's insides


def test_bar_json_parses_and_has_the_bar_types_monitors_sh_offers():
    assert {"full", "minimal"} <= set(config()["bars"])


def test_every_module_name_has_its_file():
    cfg = config()
    missing = {name for name in every_name(cfg) if not module_file(name, cfg["modules"]).exists()}
    assert missing == set()


def test_a_custom_module_runs_something_or_shows_something():
    for name, settings in config()["modules"].items():
        if settings.get("type") == "custom":
            assert settings.get("exec") or settings.get("format"), name


def test_the_scripts_custom_modules_run_are_in_the_repo():
    for name, settings in config()["modules"].items():
        for key in ("exec", "on-click", "on-click-right"):
            for script in re.findall(r"~/\.local/lib/hyprflow/([\w.-]+)", settings.get(key, "")):
                path = REPO / "lib" / script
                # A link into a submodule counts even before the submodule is fetched.
                assert path.exists() or path.is_symlink(), f"{name}: {script}"


def test_the_comment_stripper_keeps_slashes_inside_strings(tmp_path):
    f = tmp_path / "commented.json"
    f.write_text('{"a": "https://x", // the url\n "b": 1}\n')
    assert parse(f) == {"a": "https://x", "b": 1}


def test_the_chosen_style_exists_and_every_style_only_uses_base_keys():
    styles = BAR / "styles"
    base = parse(styles / "clusters.json")
    assert (styles / (config().get("style", "clusters") + ".json")).exists()
    for path in styles.glob("*.json"):
        style = parse(path)
        for key, value in style.items():
            assert key in base, f"{path.name}: {key}"
            if isinstance(value, dict):
                assert set(value) <= set(base[key]), f"{path.name}: {key}"


def test_commands_that_keep_running_die_with_quickshell():
    """A watcher or stream started by a plain Process outlives qs: each
    restart left another pw-metadata or swaync-client behind. They go through
    LongProcess (setpriv --pdeathsig) instead."""
    keep_running = ('"pw-metadata", "-m"', '"swaync-client", "-swb"', '"cava", "-p"',
                    'camera_status.py', 'mod.settings.exec')
    shell = REPO / "dotconfig" / "quickshell" / "hyprflow"
    for qml in shell.rglob("*.qml"):
        text = qml.read_text()
        for block in re.findall(r"\bProcess \{.*?\n    \}", text, re.S):
            for command in keep_running:
                assert command not in block, f"{qml.name}: {command} in a plain Process"


def test_no_ipc_function_is_called_show():
    """`qs ipc call TARGET show` is qs's own subcommand: it lists the target's
    functions and calls nothing (the bar never came back after game mode)."""
    shell = REPO / "dotconfig" / "quickshell" / "hyprflow"
    for qml in shell.rglob("*.qml"):
        for block in re.findall(r"IpcHandler \{.*?\n    \}", qml.read_text(), re.S):
            assert "function show(" not in block, qml.name


def test_a_singleton_has_no_braces_before_its_pragma():
    # Quickshell's scan then misses `pragma Singleton`: the file loads as a
    # plain type and every property reads undefined, without an error.
    for qml in (REPO / "dotconfig" / "quickshell" / "hyprflow").rglob("*.qml"):
        text = qml.read_text()
        if "pragma Singleton" in text:
            before = text.split("pragma Singleton")[0]
            assert "{" not in before and "}" not in before, qml


def test_module_loader_imports_every_folder_the_modules_use():
    # The modules load by URL, so Quickshell never scans their imports: a
    # qs.bar.X folder no static file imports is "not installed".
    loader = (BAR / "ModuleLoader.qml").read_text()
    for folder in (p for p in BAR.iterdir() if p.is_dir() and any(p.glob("*.qml"))):
        if folder.name != "modules":
            assert f"import qs.bar.{folder.name}" in loader, folder.name


NOWSPINNING = REPO / "modules" / "NowSpinning" / "nowspinning"


def test_the_full_player_skins_are_the_nowspinning_submodules():
    # MediaSkin.qml lists NowSpinning's skins by file, and its options by
    # the property each skin declares; a rename there would hide one quietly.
    media_skin = (BAR / "services" / "MediaSkin.qml").read_text()
    files = re.findall(r'file: "(\w+\.qml)"', media_skin)
    keys = re.findall(r'key: "(\w+)"', media_skin)
    assert files and keys
    if not (NOWSPINNING / "skins").is_dir():
        return  # submodule not checked out
    skins = "".join((NOWSPINNING / "skins" / f).read_text() for f in files)
    for key in keys:
        assert re.search(rf"property \w+ {key}\b", skins), key


def test_install_links_nowspinning_where_skin_face_imports_it():
    face = (BAR / "widgets" / "SkinFace.qml").read_text()
    assert 'import "../nowspinning/skins"' in face
    install = (REPO / "install.sh").read_text()
    assert 'modules/NowSpinning/nowspinning" "$CONFIG_DEST/quickshell/hyprflow/bar/nowspinning"' in install
