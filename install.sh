#!/usr/bin/env bash

# ─────────────────────────────────────────
# VARIABLES
# ─────────────────────────────────────────

REPO_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_FILES_PATH="$HOME/.local/bin"
CONFIG_DEST="$HOME/.config"

WITH_DEPS=false
WITH_PLUGINS=false
WITH_ZSH=false

# Steps asked for on the command line. With none named, everything runs.
declare -A RUN=()
FULL_RUN=false

want() { [ -n "${RUN[$1]:-}" ]; }

usage() {
    cat <<'EOF'
usage: install.sh [step...] [option...]

With no step named, the full install runs.

Steps:
  check       report missing packages, submodules and plugins
  config      copy dotfiles, link scripts, install fonts
  theme       apply the default colour palette
  lockscreen  seed the avatar and build the hyprlock layout
  monitors    run the monitor wizard
  zsh         install .zshrc, and offer to make zsh your shell

Options:
  --with-deps      install the missing packages (pacman, then yay or paru)
  --with-plugins   install the missing Hyprland plugins (compiles, slow)
  --with-zsh       include the zsh step in a full run
  -h, --help       show this

Examples:
  install.sh                  full install
  install.sh config           push the dotfiles and nothing else
  install.sh check            just tell me what is missing
  install.sh config theme     dotfiles plus a recolour
EOF
}

for arg in "$@"; do
    case "$arg" in
        check|config|theme|lockscreen|monitors|zsh) RUN[$arg]=1 ;;
        --with-deps)    WITH_DEPS=true ;;
        --with-plugins) WITH_PLUGINS=true ;;
        --with-zsh)     WITH_ZSH=true ;;
        -h|--help)      usage; exit 0 ;;
        *)
            echo "install.sh: unknown argument '$arg'" >&2
            echo "try: install.sh --help" >&2
            exit 1 ;;
    esac
done

if [ ${#RUN[@]} -eq 0 ]; then
    FULL_RUN=true
    for step in check config theme lockscreen monitors; do RUN[$step]=1; done
    [ "$WITH_ZSH" = true ] && RUN[zsh]=1
fi

# One per progress() call in the functions each step runs. Keep in sync.
TOTAL_STEPS=0
want check      && TOTAL_STEPS=$((TOTAL_STEPS + 3))   # deps, submodules, plugins
want config     && TOTAL_STEPS=$((TOTAL_STEPS + 5))   # permissions, files, rofi, runcat, binaries
want theme      && TOTAL_STEPS=$((TOTAL_STEPS + 1))
want lockscreen && TOTAL_STEPS=$((TOTAL_STEPS + 1))
want monitors   && TOTAL_STEPS=$((TOTAL_STEPS + 1))
want zsh        && TOTAL_STEPS=$((TOTAL_STEPS + 1))
if want config || want theme || want lockscreen; then
    TOTAL_STEPS=$((TOTAL_STEPS + 1))                  # reload
fi
CURRENT_STEP=0

# Packages this config needs. Checked with `pacman -T`, which understands
# provides, so rofi satisfying rofi-wayland counts as installed.
PACMAN_PKGS=(
    hyprland hyprlock hyprshot hyprpicker
    waybar rofi swaync wlogout cava awww
    kitty yazi satty btop fastfetch gnome-disk-utility
    pipewire pipewire-pulse wireplumber pavucontrol rtkit
    brightnessctl playerctl upower openconnect network-manager-applet
    gtk4 gtk4-layer-shell gnome-themes-extra polkit-gnome libnotify
    xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-hyprland
    ttf-jetbrains-mono-nerd noto-fonts-cjk gnu-free-fonts
    python python-gobject jq curl imagemagick wl-clipboard fzf
    cpio cmake pacman-contrib
)

AUR_PKGS=(
    eww-git waypaper-git wallust headsetcontrol bibata-cursor-theme-bin
)

# Hyprland plugins, in the order they are reported.
PLUGIN_NAMES=(hyprfocus hymission hyprglass)
declare -A PLUGIN_REPOS=(
    [hyprfocus]="https://github.com/hyprwm/hyprland-plugins"
    [hymission]="https://github.com/gfhdhytghd/hymission"
    [hyprglass]="https://github.com/hyprnux/hyprglass"
)

# Whatever the checks could not resolve. final_report prints these at the end,
# where they are not lost behind a dozen progress bars.
MISSING_PACMAN=()
MISSING_AUR=()
MISSING_SUBMODULES=()
MISSING_PLUGINS=()      # not installed
DISABLED_PLUGINS=()     # installed, but not enabled

# ─────────────────────────────────────────
# PROGRESS BAR
# ─────────────────────────────────────────

progress() {
    local label="$1"
    CURRENT_STEP=$(( CURRENT_STEP + 1 ))
    local percent=$(( CURRENT_STEP * 100 / TOTAL_STEPS ))
    local width=36
    local filled=$(( CURRENT_STEP * width / TOTAL_STEPS ))
    [ "$percent" -gt 100 ] && percent=100
    [ "$filled" -gt "$width" ] && filled=$width
    local empty=$(( width - filled ))
    local filled_str="" empty_str=""
    for ((i=0; i<filled; i++)); do filled_str+="█"; done
    for ((i=0; i<empty; i++)); do empty_str+="░"; done
    printf "\n\033[1;32m[%s\033[90m%s\033[1;32m]\033[0m \033[1m%3d%%\033[0m  \033[1;36m%s\033[0m\n\n" \
        "$filled_str" "$empty_str" "$percent" "$label"
}

# ─────────────────────────────────────────
# FUNCTIONS
# ─────────────────────────────────────────

# ── Dependencies ─────────────────────────

aur_helper() {
    command -v yay  >/dev/null 2>&1 && { echo yay;  return 0; }
    command -v paru >/dev/null 2>&1 && { echo paru; return 0; }
    return 1
}

check_dependencies() {
    progress "DEPENDENCIES"

    if ! command -v pacman >/dev/null 2>&1; then
        echo "󰀦 Not an Arch system, skipping the dependency check."
        return 0
    fi

    # pacman -T prints only the packages that are not satisfied.
    mapfile -t MISSING_PACMAN < <(pacman -T "${PACMAN_PKGS[@]}")
    mapfile -t MISSING_AUR    < <(pacman -T "${AUR_PKGS[@]}")

    if [ ${#MISSING_PACMAN[@]} -eq 0 ] && [ ${#MISSING_AUR[@]} -eq 0 ]; then
        echo "󰄬 All packages installed."
        return 0
    fi

    [ ${#MISSING_PACMAN[@]} -gt 0 ] && echo "󰀦 Missing from the repos: ${MISSING_PACMAN[*]}"
    [ ${#MISSING_AUR[@]} -gt 0 ]    && echo "󰀦 Missing from the AUR: ${MISSING_AUR[*]}"

    if [ "$WITH_DEPS" != true ]; then
        echo "   Re-run with --with-deps to install them; listed again at the end."
        return 0
    fi

    install_dependencies
}

install_dependencies() {
    local helper

    if [ ${#MISSING_PACMAN[@]} -gt 0 ]; then
        echo "󰑓 sudo pacman -S --needed ${MISSING_PACMAN[*]}"
        sudo pacman -S --needed "${MISSING_PACMAN[@]}" || true
        mapfile -t MISSING_PACMAN < <(pacman -T "${PACMAN_PKGS[@]}")
    fi

    [ ${#MISSING_AUR[@]} -gt 0 ] || return 0

    if ! helper="$(aur_helper)"; then
        echo "󰀦 No AUR helper found (yay or paru); install those by hand."
        return 0
    fi

    echo "󰑓 $helper -S --needed ${MISSING_AUR[*]}"
    "$helper" -S --needed "${MISSING_AUR[@]}" || true
    mapfile -t MISSING_AUR < <(pacman -T "${AUR_PKGS[@]}")
}

# ── Submodules ───────────────────────────

# A clone without --recursive leaves modules/* empty. That is quiet damage: the
# rofi fonts never copy, the runcat font never installs, and the symlinks for
# claude-usage.sh / sinkswitch / trackpad-battery are skipped without a word.
# So check them out here instead of warning and carrying on regardless.
missing_submodules() {
    local path
    # Read .gitmodules directly: detection must work even without git, so that
    # the summary can still tell you what is missing.
    while IFS= read -r path; do
        # .git is the checkout marker; the folder itself exists either way.
        [ -e "$REPO_PATH/$path/.git" ] || printf '%s\n' "$path"
    done < <(awk -F= '/^[[:space:]]*path[[:space:]]*=/ {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2
    }' "$REPO_PATH/.gitmodules")
}

check_submodules() {
    progress "SUBMODULES"

    if [ ! -f "$REPO_PATH/.gitmodules" ]; then
        echo "󰄬 No submodules declared."
        return 0
    fi

    mapfile -t MISSING_SUBMODULES < <(missing_submodules)
    if [ ${#MISSING_SUBMODULES[@]} -eq 0 ]; then
        echo "󰄬 All submodules checked out."
        return 0
    fi

    echo "󰑓 Fetching ${MISSING_SUBMODULES[*]}"
    git -C "$REPO_PATH" submodule update --init --recursive || true

    mapfile -t MISSING_SUBMODULES < <(missing_submodules)
    if [ ${#MISSING_SUBMODULES[@]} -eq 0 ]; then
        echo "󰄬 Submodules checked out."
    else
        echo "󰀦 Could not fetch: ${MISSING_SUBMODULES[*]}"
    fi
}

# ── Plugins ──────────────────────────────

# Prints "enabled", "disabled", or nothing when hyprpm does not know the plugin.
plugin_state() {
    hyprpm list 2>/dev/null | awk -v name="$1" '
        /Plugin/ && $NF == name { found = 1; next }
        found && /enabled:/     { print ($0 ~ /true/) ? "enabled" : "disabled"; exit }
    '
}

# Sorts every plugin into enabled / disabled / missing, printing as it goes.
read_plugin_states() {
    local name
    MISSING_PLUGINS=()
    DISABLED_PLUGINS=()

    for name in "${PLUGIN_NAMES[@]}"; do
        case "$(plugin_state "$name")" in
            enabled)  echo "󰄬 $name" ;;
            disabled) echo "󰀦 $name is installed but disabled"
                      DISABLED_PLUGINS+=("$name") ;;
            *)        echo "󰀦 $name is not installed"
                      MISSING_PLUGINS+=("$name") ;;
        esac
    done
}

# hyprpm compiles every plugin against the running Hyprland, which is slow and
# can fail, so the default is to report and let you decide.
check_plugins() {
    progress "PLUGINS"

    if ! command -v hyprpm >/dev/null 2>&1 || ! hyprctl version >/dev/null 2>&1; then
        echo "󰀦 hyprpm missing or Hyprland not running, skipping the plugin check."
        return 0
    fi

    read_plugin_states
    [ $(( ${#MISSING_PLUGINS[@]} + ${#DISABLED_PLUGINS[@]} )) -gt 0 ] || return 0

    if [ "$WITH_PLUGINS" != true ]; then
        echo "   Re-run with --with-plugins to install them; listed again at the end."
        return 0
    fi

    install_plugins
}

install_plugins() {
    local name
    echo "󰑓 Installing plugins with hyprpm; this compiles them and takes a while."
    hyprpm update || true

    for name in "${MISSING_PLUGINS[@]}"; do
        hyprpm add "${PLUGIN_REPOS[$name]}" || true
    done
    for name in "${MISSING_PLUGINS[@]}" "${DISABLED_PLUGINS[@]}"; do
        hyprpm enable "$name" || true
    done

    # Re-read the real state instead of assuming the commands worked.
    read_plugin_states
}

set_permissions() {
    progress "PERMISSIONS"
    echo "󰒓 Setting execute permissions on scripts..."
    find "$REPO_PATH/bin" -type f -exec chmod +x {} \;
    # Lockscreen helpers ship inside dotconfig, not bin, because only
    # hyprlock-flow.sh is meant to be invoked directly.
    find "$REPO_PATH/dotconfig/hypr/hyprlock" -type f -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true

    while IFS= read -r -d '' link; do
        target="$(readlink -f "$link" 2>/dev/null || true)"
        if [ -n "$target" ] && [ -f "$target" ]; then
            chmod +x "$target"
        fi
    done < <(find "$REPO_PATH/bin" -maxdepth 1 -type l -print0)
}

copy_configs() {
    progress "CONFIG FILES"
    echo "󰆐 Copying configuration files..."

    local mon_active="$CONFIG_DEST/hypr/monitors_active.lua"
    local waybar_cfg="$CONFIG_DEST/waybar/config"
    # Both are generated per monitor set, and the repo ships single-bar
    # fallbacks that would overwrite them. Hold on to yours unless the monitors
    # step is going to regenerate them anyway.
    local mon_backup="" wb_backup=""
    if ! want monitors; then
        [ -f "$mon_active" ]  && mon_backup="$(cat "$mon_active")"
        [ -f "$waybar_cfg" ]  && wb_backup="$(cat "$waybar_cfg")"
    fi

    cp -rf "$REPO_PATH/dotconfig"/* "$CONFIG_DEST/"

    [ -n "$mon_backup" ] && printf '%s' "$mon_backup" > "$mon_active"
    [ -n "$wb_backup"  ] && printf '%s' "$wb_backup"  > "$waybar_cfg"

    echo "󰆐 Copying eww configuration..."
    mkdir -p "$CONFIG_DEST/eww"
    cp -rf "$REPO_PATH/dotconfig/eww"/* "$CONFIG_DEST/eww/"

    echo "󰄛 Copying kitty configuration..."
    mkdir -p "$CONFIG_DEST/kitty"
    cp -rf "$REPO_PATH/dotconfig/kitty"/* "$CONFIG_DEST/kitty/" 2>/dev/null || true

    echo "󰆐 Copying xdg-desktop-portal configuration..."
    mkdir -p "$CONFIG_DEST/xdg-desktop-portal"
    cp -rf "$REPO_PATH/dotconfig/xdg-desktop-portal"/* "$CONFIG_DEST/xdg-desktop-portal/"

    echo "󰚌 Copying fastfetch configuration..."
    mkdir -p "$CONFIG_DEST/fastfetch"
    cp -rf "$REPO_PATH/dotconfig/fastfetch"/* "$CONFIG_DEST/fastfetch/"
}

setup_rofi() {
    progress "ROFI"
    echo "󰍉 Copying rofi-collection module..."
    mkdir -p "$CONFIG_DEST/rofi"
    cp -rf "$REPO_PATH/modules/rofi-collection"/files/* "$CONFIG_DEST/rofi/" 2>/dev/null || true

    echo "󰛖 Installing rofi fonts..."
    local font_dir="$HOME/.local/share/fonts"
    mkdir -p "$font_dir"
    cp -rf "$REPO_PATH/modules/rofi-collection/fonts"/* "$font_dir/" 2>/dev/null || true
    fc-cache -f "$font_dir"

    echo "󰏘 Applying custom Rofi themes..."
    local rofi_custom="$REPO_PATH/dotconfig/rofi"
    if [ -d "$rofi_custom" ]; then
        cp -rf "$rofi_custom"/* "$CONFIG_DEST/rofi/"
    fi
}

setup_runcat() {
    progress "RUNCAT"
    # config.json lives inside the submodule, so edits there don't survive a
    # `git submodule update` or fresh clone. Keep the editable copy here and
    # reapply it on every install.
    local font_dir="$HOME/.local/share/fonts"
    mkdir -p "$font_dir"

    # The chicken runner lives in this repo, so it installs either way.
    cp -f "$REPO_PATH/dotconfig/waybar/runcat-chicken.ttf" "$font_dir/"

    if [ -d "$REPO_PATH/modules/runcat-text" ]; then
        echo "󰄛 Applying runcat-text config..."
        cp -f "$REPO_PATH/dotconfig/waybar/runcat-config.json" "$REPO_PATH/modules/runcat-text/config.json"

        echo "󰛖 Installing runcat-text fonts..."
        cp -f "$REPO_PATH/modules/runcat-text/runcat.ttf" "$font_dir/"
    else
        printf "\033[1;33m%s runcat-text submodule missing, installing the chicken runner only.\033[0m\n" "󰀦"
    fi

    fc-cache -f "$font_dir"
}

create_symlinks() {
    progress "BINARIES"
    echo "󰌹 Creating symbolic links for binaries..."
    local broken=()
    for file in "$REPO_PATH/bin"/*; do
        # Directories too: session-manager/ is invoked as
        # ~/.local/bin/session-manager/save.sh from the keybindings.
        if [ -f "$file" ] || [ -d "$file" ]; then
            ln -sfn "$file" "$BIN_FILES_PATH/$(basename "$file")"
        elif [ -L "$file" ]; then
            # -f follows the link, so a dangling one lands here: its submodule
            # is not checked out. Say so instead of skipping in silence.
            broken+=("$(basename "$file")")
        fi
    done

    if [ ${#broken[@]} -gt 0 ]; then
        printf "\033[1;33m%s Skipped, submodule missing: %s\033[0m\n" "󰀦" "${broken[*]}"
    fi
}

apply_theme() {
    progress "THEME"
    echo "󰏘 Setting up colors..."
    # --no-restart: we bounce Waybar once at the end, not once per step.
    "$REPO_PATH/bin/wallust-theme-manager.sh" --restore-default --notify --no-restart 2>/dev/null || true

    echo "󰆐 Copying color templates to wallust cache..."
    local colors_src="$REPO_PATH/dotconfig/wallust/colors"
    if [ -d "$colors_src" ]; then
        cp "$colors_src"/* "$HOME/.cache/wallust/colors/" 2>/dev/null || true
    fi
}

setup_lockscreen() {
    progress "LOCKSCREEN"

    # Seed the default avatar before geometry.sh runs, since that would
    # otherwise draw the Arch glyph fallback. Only when nothing is there:
    # an existing avatar is the user's own and is never replaced.
    local avatar="$CONFIG_DEST/hypr/avatar.png"
    if [ ! -f "$avatar" ] && [ -f "$REPO_PATH/assets/avatar.png" ]; then
        echo "󰭄 Installing default avatar..."
        mkdir -p "$CONFIG_DEST/hypr"
        cp "$REPO_PATH/assets/avatar.png" "$avatar"
    fi

    echo "󰌾 Generating hyprlock geometry and backdrop..."
    # hyprlock.conf sources hyprlock-geometry.conf and hyprlock-extras.conf,
    # both generated, so a clean install would start with them missing. Runs
    # after apply_theme because the avatar picks up the palette colour, and
    # calls the installed copy so the paths it writes match runtime.
    "$CONFIG_DEST/hypr/hyprlock/geometry.sh" 2>/dev/null || true
}

setup_monitors() {
    progress "MONITORS"
    # The wizard asks questions, so it needs a terminal. Piped or unattended,
    # fall back to the saved profile instead of hanging on a prompt.
    if [ -t 0 ]; then
        echo "󰍹 Configuring monitors..."
        "$REPO_PATH/bin/monitors.sh" setup || "$REPO_PATH/bin/monitors.sh" apply || true
    else
        echo "󰍹 Applying monitor layout (saved profile / default)..."
        "$REPO_PATH/bin/monitors.sh" apply 2>/dev/null || true
    fi
}

reload_hyprland() {
    progress "RELOAD"
    echo "󰑓 Reloading Hyprpm..."
    hyprpm reload

    echo "󰑓 Reloading Hyprland..."
    hyprctl reload
}

setup_zsh() {
    progress "ZSH"
    local src="$REPO_PATH/dotconfig/zsh/.zshrc"
    local dest="$HOME/.zshrc"
    local reply zsh_path

    # This one touches your shell, not just ~/.config, so it always asks.
    if [ -f "$dest" ]; then
        read -r -p "  ~/.zshrc already exists. Overwrite? [y/N] " reply
        if [[ ! "$reply" =~ ^[Yy]$ ]]; then
            echo "  Skipped."
            return 0
        fi
        cp "$dest" "$dest.bak"
        echo "  Backup saved to ~/.zshrc.bak"
    fi

    cp "$src" "$dest"
    echo "󰄬 ~/.zshrc installed."

    zsh_path="$(command -v zsh)" || return 0
    if [ "$SHELL" != "$zsh_path" ]; then
        read -r -p "  Set zsh as your default shell? [y/N] " reply
        [[ "$reply" =~ ^[Yy]$ ]] && chsh -s "$zsh_path"
    fi
}

restart_waybar() {
    killall waybar 2>/dev/null || true
    # waybar spawns cava but never reaps it.
    killall cava 2>/dev/null || true
    sleep 0.5

    # Never 'setsid waybar &': that inherits this script's environment, which
    # may carry a sandbox's GTK_PATH and kill waybar on startup. hyprctl runs it
    # from the compositor instead. With hyprlang-lua, 'exec waybar' parses as
    # Lua and fails, hence the lua form first.
    if command -v hyprctl >/dev/null 2>&1; then
        if hyprctl dispatch 'hl.dsp.exec_cmd("waybar")' 2>/dev/null | grep -q '^ok'; then
            return 0
        fi
        if hyprctl dispatch exec waybar 2>/dev/null | grep -q '^ok'; then
            return 0
        fi
    fi

    # No Hyprland to hand: at least strip the sandbox variables.
    env -u GTK_PATH -u LOCPATH -u GTK_EXE_PREFIX -u GDK_PIXBUF_MODULEDIR \
        -u GDK_PIXBUF_MODULE_FILE -u GIO_MODULE_DIR -u GTK_IM_MODULE_FILE \
        -u GSETTINGS_SCHEMA_DIR -u SNAP -u SNAP_NAME -u SNAP_LIBRARY_PATH \
        setsid waybar >/dev/null 2>&1 < /dev/null &
}

# ─────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────

if [ "$FULL_RUN" = true ]; then
    echo "󰣇 Installing HyprFlow-Arch..."
else
    echo "󰣇 HyprFlow-Arch: ${!RUN[*]}"
fi
mkdir -p "$BIN_FILES_PATH" "$CONFIG_DEST" "$HOME/Pictures/Screenshots"

if want check; then
    check_dependencies
    check_submodules
    check_plugins
fi

if want config; then
    set_permissions
    copy_configs
    setup_rofi
    setup_runcat
    create_symlinks
fi

want theme      && apply_theme
want lockscreen && setup_lockscreen

# Anything that rewrote files under ~/.config needs the compositor to re-read them.
if want config || want theme || want lockscreen; then
    reload_hyprland
fi

want monitors && setup_monitors
want zsh      && setup_zsh

# monitors.sh restarts Waybar itself after regenerating the bars, so only do it
# here when that step did not run.
if ! want monitors && { want config || want theme; }; then
    restart_waybar
fi

final_report() {
    local pending name
    pending=$(( ${#MISSING_PACMAN[@]} + ${#MISSING_AUR[@]} + ${#MISSING_SUBMODULES[@]} +
                ${#MISSING_PLUGINS[@]} + ${#DISABLED_PLUGINS[@]} ))

    if [ "$pending" -eq 0 ]; then
        if [ "$FULL_RUN" = true ]; then
            printf "\n\033[1;32m󰄬 Installation complete!\033[0m\n"
        else
            printf "\n\033[1;32m󰄬 Done.\033[0m\n"
        fi
        return 0
    fi

    printf "\n\033[1;33m󰀦 Installation finished, with things left to do:\033[0m\n\n"

    [ ${#MISSING_PACMAN[@]} -gt 0 ] &&
        printf "   sudo pacman -S --needed %s\n" "${MISSING_PACMAN[*]}"
    [ ${#MISSING_AUR[@]} -gt 0 ] &&
        printf "   yay -S --needed %s\n" "${MISSING_AUR[*]}"
    [ ${#MISSING_SUBMODULES[@]} -gt 0 ] &&
        printf "   git submodule update --init --recursive   (%s)\n" "${MISSING_SUBMODULES[*]}"

    for name in "${MISSING_PLUGINS[@]}"; do
        printf "   hyprpm add %s && hyprpm enable %s\n" "${PLUGIN_REPOS[$name]}" "$name"
    done
    for name in "${DISABLED_PLUGINS[@]}"; do
        printf "   hyprpm enable %s\n" "$name"
    done

    printf "\n   Or re-run: bash install.sh --with-deps --with-plugins\n"
}
final_report
