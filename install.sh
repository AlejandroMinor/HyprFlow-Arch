#!/usr/bin/env bash

# ─────────────────────────────────────────
# VARIABLES
# ─────────────────────────────────────────

REPO_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_FILES_PATH="$HOME/.local/bin"
CONFIG_DEST="$HOME/.config"

SKIP_THEME=false
SKIP_MONITORS=false
for arg in "$@"; do
    case "$arg" in
        --skip-theme)    SKIP_THEME=true ;;
        --skip-monitors) SKIP_MONITORS=true ;;
    esac
done

TOTAL_STEPS=7
[ "$SKIP_THEME" = true ] && TOTAL_STEPS=$((TOTAL_STEPS - 1))
CURRENT_STEP=0

# ─────────────────────────────────────────
# PROGRESS BAR
# ─────────────────────────────────────────

progress() {
    local label="$1"
    CURRENT_STEP=$(( CURRENT_STEP + 1 ))
    local percent=$(( CURRENT_STEP * 100 / TOTAL_STEPS ))
    local width=36
    local filled=$(( CURRENT_STEP * width / TOTAL_STEPS ))
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

set_permissions() {
    progress "PERMISSIONS"
    echo "󰒓 Setting execute permissions on scripts..."
    find "$REPO_PATH/bin" -type f -exec chmod +x {} \;

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
    local mon_backup="" wb_backup=""
    if [ "$SKIP_MONITORS" = true ]; then
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
    cp -rf "$REPO_PATH/modules/rofi-collection/fonts"/* "$font_dir/"
    fc-cache -f "$font_dir"

    echo "󰏘 Applying custom Rofi themes..."
    local rofi_custom="$REPO_PATH/dotconfig/rofi"
    if [ -d "$rofi_custom" ]; then
        cp -rf "$rofi_custom"/* "$CONFIG_DEST/rofi/"
    fi
}

create_symlinks() {
    progress "BINARIES"
    echo "󰌹 Creating symbolic links for binaries..."
    for file in "$REPO_PATH/bin"/*; do
        [ -f "$file" ] && ln -sf "$file" "$BIN_FILES_PATH/$(basename "$file")"
    done
}

apply_theme() {
    progress "THEME"
    echo "󰏘 Setting up colors..."
    "$REPO_PATH/bin/wallust-theme-manager.sh" --restore-default --notify 2>/dev/null || true

    echo "󰆐 Copying color templates to wallust cache..."
    local colors_src="$REPO_PATH/dotconfig/wallust/colors"
    if [ -d "$colors_src" ]; then
        cp "$colors_src"/* "$HOME/.cache/wallust/colors/" 2>/dev/null || true
    fi
}

setup_monitors() {
    progress "MONITORS"
    if [ "$SKIP_MONITORS" = true ]; then
        echo "󰍹 Applying monitor layout (saved profile / default)..."
        "$REPO_PATH/bin/monitors.sh" apply 2>/dev/null || true
    else
        echo "󰍹 Configuring monitors (run with --skip-monitors to skip)..."
        "$REPO_PATH/bin/monitors.sh" setup || "$REPO_PATH/bin/monitors.sh" apply || true
    fi
}

reload_hyprland() {
    progress "RELOAD"
    echo "󰑓 Reloading Hyprpm..."
    hyprpm reload

    echo "󰑓 Reloading Hyprland..."
    hyprctl reload
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

echo "󰣇 Installing HyprFlow-Arch..."
mkdir -p "$BIN_FILES_PATH" "$CONFIG_DEST" "$HOME/Pictures/Screenshots"

set_permissions
copy_configs
setup_rofi
create_symlinks

if [ "$SKIP_THEME" = false ]; then
    apply_theme
fi


reload_hyprland
setup_monitors
restart_waybar

printf "\n\033[1;32m󰄬 Installation complete!\033[0m\n"
