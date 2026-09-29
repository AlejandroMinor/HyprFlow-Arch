"""Tests for install.sh. It runs for real, but against a throwaway $HOME and a
PATH whose first entry holds fake pacman, sudo, yay, hyprctl, killall...
Each fake logs how it was called, so the tests check what the installer
asked for without installing, reloading or killing anything."""

import os
import pty
import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent
INSTALL = REPO / "install.sh"

# Every fake appends "name args" to $FAKE_LOG. $FAKE_MISSING lists the packages
# pacman -T reports as missing; installing one removes it from that file.
FAKES = {
    "pacman": """
        if [ "$1" = -T ]; then
            shift
            for p in "$@"; do grep -qx -- "$p" "$FAKE_MISSING" && echo "$p"; done
            exit 0
        fi
        if [ "$1" = -S ]; then
            shift 2
            for p in "$@"; do sed -i "/^$p\\$/d" "$FAKE_MISSING"; done
        fi
    """,
    "yay": """
        [ -n "${FAKE_AUR_FAIL:-}" ] && exit 1
        shift 2
        for p in "$@"; do sed -i "/^$p\\$/d" "$FAKE_MISSING"; done
    """,
    "sudo": 'exec "$@"',
    # No `version` answer: Hyprland "not running", so the plugin check skips.
    # FAKE_RELOAD_FAIL: Hyprland refuses the reload.
    "hyprctl": '[ "$1" = dispatch ] && echo ok; [ "$1" = version ] && exit 1; '
               '[ "$1" = reload ] && [ -n "${FAKE_RELOAD_FAIL:-}" ] && { echo "no socket" >&2; exit 1; }; exit 0',
    "hyprpm": "",
    "killall": "",
    "fc-cache": "",
    "notify-send": "",
    "rgb-sync.sh": "",
    "gsettings": "",
    # Writes one of the cached palette files, as a real run writes them all.
    "wallust": 'mkdir -p "$HOME/.cache/wallust/colors"; echo fresh > "$HOME/.cache/wallust/colors/colors-waybar.css"',
}


@pytest.fixture
def env(tmp_path):
    fakes = tmp_path / "fakebin"
    fakes.mkdir()
    for name, body in FAKES.items():
        script = fakes / name
        script.write_text(f'#!/bin/bash\necho "{name} $*" >> "$FAKE_LOG"\n{body}\n')
        script.chmod(0o755)
    home = tmp_path / "home"
    home.mkdir()
    (tmp_path / "missing").write_text("")
    (tmp_path / "log").write_text("")
    environ = {k: v for k, v in os.environ.items()
               if not k.startswith(("XDG_CONFIG", "HYPRLAND_"))}
    environ.update(HOME=str(home), PATH=f"{fakes}:{os.environ['PATH']}",
                   FAKE_LOG=str(tmp_path / "log"), FAKE_MISSING=str(tmp_path / "missing"))
    return environ


def missing(env, *pkgs):
    Path(env["FAKE_MISSING"]).write_text("".join(f"{p}\n" for p in pkgs))


def log(env):
    return Path(env["FAKE_LOG"]).read_text().splitlines()


def run(env, *args):
    """Without a terminal on stdin, as from a pipe."""
    return subprocess.run(["bash", str(INSTALL), *args], env=env, text=True,
                          stdin=subprocess.DEVNULL, capture_output=True, timeout=60)


def run_tty(env, *args, answers):
    """With a terminal on stdin, answering the prompts in order."""
    master, slave = pty.openpty()
    try:
        os.write(master, "".join(f"{a}\n" for a in answers).encode())
        return subprocess.run(["bash", str(INSTALL), *args], env=env, text=True,
                              stdin=slave, capture_output=True, timeout=60)
    finally:
        os.close(master)
        os.close(slave)


def test_check_with_everything_installed(env):
    result = run(env, "check")
    assert result.returncode == 0
    assert "All packages installed" in result.stdout
    assert "MISSING PACKAGES" not in result.stdout


def test_check_alone_reports_without_asking(env):
    missing(env, "jq", "wallust")
    result = run(env, "check")
    assert result.returncode == 0
    assert "MISSING PACKAGES" in result.stdout
    assert "jq" in result.stdout and "wallust" in result.stdout
    assert "Install them now?" not in result.stdout + result.stderr
    assert not any(line.startswith(("sudo", "yay")) for line in log(env))


def test_stops_without_a_terminal_before_copying(env):
    missing(env, "jq")
    result = run(env, "check", "config")
    assert result.returncode == 1
    assert "Install stopped" in result.stdout
    assert not (Path(env["HOME"]) / ".config" / "hypr").exists()


def test_installs_then_asks_to_continue_with_what_failed(env):
    env["FAKE_AUR_FAIL"] = "1"
    missing(env, "jq", "wallust")
    result = run_tty(env, "check", "config", answers=["y", "n"])
    assert result.returncode == 1
    assert "sudo pacman -S --needed jq" in log(env)
    assert "yay -S --needed wallust" in log(env)
    # jq went in, wallust did not: only wallust is left to ask about.
    assert "Continue the install without them?" in result.stderr
    assert Path(env["FAKE_MISSING"]).read_text() == "wallust\n"
    assert not (Path(env["HOME"]) / ".config" / "hypr").exists()


def test_declining_both_prompts_installs_nothing(env):
    missing(env, "jq")
    result = run_tty(env, "check", "config", answers=["n", "n"])
    assert result.returncode == 1
    assert not any(line.startswith("sudo") for line in log(env))


def test_with_deps_installs_without_asking_and_goes_on(env):
    missing(env, "jq")
    result = run(env, "check", "config", "--with-deps")
    assert result.returncode == 0, result.stdout + result.stderr
    assert "Install them now?" not in result.stdout + result.stderr
    assert "sudo pacman -S --needed jq" in log(env)
    assert (Path(env["HOME"]) / ".config" / "hypr" / "hyprland.lua").exists()


def test_check_alone_with_deps_installs(env):
    missing(env, "jq")
    result = run(env, "check", "--with-deps")
    assert result.returncode == 0, result.stdout + result.stderr
    assert "sudo pacman -S --needed jq" in log(env)
    assert "Re-run with --with-deps" not in result.stdout


def test_a_failed_step_is_reported_not_passed_over(env):
    # geometry.sh finds no monitor through the fake hyprctl and gives up.
    result = run(env, "config", "lockscreen")
    assert result.returncode == 0, result.stdout + result.stderr
    assert "geometry.sh failed:" in result.stdout
    assert "Installation complete" not in result.stdout and "Done." not in result.stdout
    assert "~/.config/hypr/hyprlock/geometry.sh" in result.stdout.split("things left to do")[1]


def test_config_stops_copying_when_it_cannot_make_a_temp_folder(env):
    fake = Path(env["PATH"].split(":")[0]) / "mktemp"
    fake.write_text("#!/bin/bash\nexit 1\n")
    fake.chmod(0o755)
    result = run(env, "config")
    assert "Could not create a temporary folder" in result.stdout
    assert not (Path(env["HOME"]) / ".config" / "hypr").exists()
    assert "install.sh config" in result.stdout.split("things left to do")[1]


def test_a_failed_reload_is_reported(env):
    env["FAKE_RELOAD_FAIL"] = "1"
    result = run(env, "config")
    assert "hyprctl failed: no socket" in result.stdout
    assert "hyprctl reload" in result.stdout.split("things left to do")[1]


def test_config_links_bin_on_path_and_lib_off_it(env):
    result = run(env, "config")
    assert result.returncode == 0, result.stdout + result.stderr
    home = Path(env["HOME"])
    bin_links = {p.name for p in (home / ".local" / "bin").iterdir()}
    lib_links = {p.name for p in (home / ".local" / "lib" / "hyprflow").iterdir()}
    assert "monitors.sh" in bin_links
    assert "battery-hub.py" in lib_links and "session-manager.py" in lib_links
    assert "battery-hub.py" not in bin_links
    assert "__pycache__" not in lib_links


def test_config_removes_only_dangling_links_into_the_repo(env):
    bin_dir = Path(env["HOME"]) / ".local" / "bin"
    bin_dir.mkdir(parents=True)
    (bin_dir / "moved.sh").symlink_to(REPO / "bin" / "moved.sh")
    (bin_dir / "someone-else").symlink_to("/nonexistent/tool")
    run(env, "config")
    lib_dir = Path(env["HOME"]) / ".local" / "lib" / "hyprflow"
    (lib_dir / "gone.py").symlink_to(REPO / "lib" / "gone.py")
    run(env, "config")
    assert not (bin_dir / "moved.sh").is_symlink()
    assert not (lib_dir / "gone.py").is_symlink()
    assert (bin_dir / "someone-else").is_symlink()


def test_config_never_touches_the_real_session(env):
    run(env, "config")
    calls = log(env)
    assert "hyprctl reload" in calls
    assert "killall -w waybar" in calls
    assert "hyprctl dispatch hl.dsp.exec_cmd(\"waybar\")" in calls


GENERATED = ["hypr/colors.lua", "rofi/hyprflow/colors.rasi", "wlogout/colors.css",
             "cava/themes/wallust", "hypr/monitors_active.lua", "waybar/config"]


def test_config_keeps_what_was_generated_on_this_machine(env):
    config = Path(env["HOME"]) / ".config"
    for path in GENERATED:
        (config / path).parent.mkdir(parents=True, exist_ok=True)
        (config / path).write_text("mine\n")
    run(env, "config")
    assert {p: (config / p).read_text() for p in GENERATED} == {p: "mine\n" for p in GENERATED}


def test_a_fresh_config_gets_the_repo_starting_copies(env):
    run(env, "config")
    config = Path(env["HOME"]) / ".config"
    for path in GENERATED:
        assert (config / path).read_bytes() == (REPO / "dotconfig" / path).read_bytes(), path


def test_theme_keeps_the_palette_wallust_just_wrote(env):
    result = run(env, "config", "theme")
    assert result.returncode == 0, result.stdout + result.stderr
    cache = Path(env["HOME"]) / ".cache" / "wallust" / "colors"
    assert (cache / "colors-waybar.css").read_text() == "fresh\n"
    # What wallust did not write is filled in from the repo.
    assert (cache / "colors-rofi-sh.conf").read_bytes() == \
        (REPO / "dotconfig" / "wallust" / "colors" / "colors-rofi-sh.conf").read_bytes()


def test_theme_turns_gtk_apps_dark(env):
    run(env, "config", "theme")
    calls = log(env)
    assert "gsettings set org.gnome.desktop.interface color-scheme prefer-dark" in calls
    assert "gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark" in calls


def test_config_ships_dark_qt_and_the_pinentry_choice(env):
    run(env, "config")
    config = Path(env["HOME"]) / ".config"
    for version in (5, 6):
        text = (config / f"qt{version}ct" / f"qt{version}ct.conf").read_text()
        assert "style=Fusion" in text and "colors/darker.conf" in text
        # qt*ct needs the stylesheet path absolute; the repo writes it with ~.
        sheet = f"{env['HOME']}/.config/qt{version}ct/qss/hyprflow.qss"
        assert f"stylesheets={sheet}" in text
        assert Path(sheet).exists()
    assert (config / "pinentry" / "preexec").exists()


def test_the_package_files_are_the_list_install_sh_checks(env):
    """install.sh reads packages/*.txt, comments and blank lines aside."""
    missing(env, "wallust", "qt6ct")
    result = run(env, "check")
    assert "qt6ct" in result.stdout and "wallust" in result.stdout
    calls = [line for line in log(env) if line.startswith("pacman -T")]
    listed = set(calls[0].split()[2:]) | set(calls[1].split()[2:])
    for name in ("pacman.txt", "aur.txt"):
        for line in (REPO / "packages" / name).read_text().splitlines():
            package = line.split("#")[0].strip()
            if package:
                assert package in listed, package


def test_the_readme_copy_and_paste_lines_match_the_package_files():
    """The README lists the packages in full, to copy and paste from anywhere;
    this keeps that copy in step with packages/*.txt."""
    readme = (REPO / "README.md").read_text()
    for name, command in (("pacman.txt", "sudo pacman -S --needed "), ("aur.txt", "yay -S --needed ")):
        wanted = [line.split("#")[0].strip() for line in (REPO / "packages" / name).read_text().splitlines()]
        wanted = [package for package in wanted if package]
        line = next(line for line in readme.splitlines() if line.startswith(command))
        assert line[len(command):].split() == wanted, f"README out of step with packages/{name}"
