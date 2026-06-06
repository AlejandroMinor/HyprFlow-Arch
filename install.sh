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
    cp -rf "$REPO_PATH/dotconfig"/* "$CONFIG_DEST/"

    echo "󰆐 Copying eww configuration..."
    mkdir -p "$CONFIG_DEST/eww"
    cp -rf "$REPO_PATH/dotconfig/eww"/* "$CONFIG_DEST/eww/"

    echo "󰄛 Copying kitty configuration..."
    mkdir -p "$CONFIG_DEST/kitty"
    cp -rf "$REPO_PATH/dotconfig/kitty"/* "$CONFIG_DEST/kitty/" 2>/dev/null || true

    echo "󰆐 Copying xdg-desktop-portal configuration..."
    mkdir -p "$CONFIG_DEST/xdg-desktop-portal"
    cp -rf "$REPO_PATH/dotconfig/xdg-desktop-portal"/* "$CONFIG_DEST/xdg-desktop-portal/"
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
killall waybar 2>/dev/null || true
sleep 0.5
setsid waybar >/dev/null 2>&1 < /dev/null &

printf "\n\033[1;32m󰄬 Installation complete!\033[0m\n"
