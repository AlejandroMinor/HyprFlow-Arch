#!/usr/bin/env bash

REPO_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_FILES_PATH="$HOME/.local/bin"
CONFIG_DEST="$HOME/.config"

SKIP_THEME=false
for arg in "$@"; do
    case "$arg" in
        --skip-theme) SKIP_THEME=true ;;
    esac
done

echo "󰣇 Installing HyprFlow-Arch..."

mkdir -p "$BIN_FILES_PATH"
mkdir -p "$CONFIG_DEST"

# Set execute permissions on all binary files first
echo "󰒓 Setting execute permissions on scripts..."
find "$REPO_PATH/bin" -type f -exec chmod +x {} \;

# Ensure symlinked binaries in bin point to executable targets
while IFS= read -r -d '' link; do
    target="$(readlink -f "$link" 2>/dev/null || true)"
    if [ -n "$target" ] && [ -f "$target" ]; then
        chmod +x "$target"
    fi
done < <(find "$REPO_PATH/bin" -maxdepth 1 -type l -print0)

# Copy configuration files (dotconfig -> ~/.config)
echo "󰆐 Copying configuration files..."
cp -rf "$REPO_PATH/dotconfig"/* "$CONFIG_DEST/"

# Copy eww config
echo "󰆐 Copying eww configuration..."
mkdir -p "$CONFIG_DEST/eww"
cp -rf "$REPO_PATH/dotconfig/eww"/* "$CONFIG_DEST/eww/"

# Copy kitty config
echo "󰄛 Copying kitty configuration..."
mkdir -p "$CONFIG_DEST/kitty"
cp -rf "$REPO_PATH/dotconfig/kitty"/* "$CONFIG_DEST/kitty/" 2>/dev/null || true

# Copy xdg-desktop-portal config
echo "󰆐 Copying xdg-desktop-portal configuration..."
mkdir -p "$CONFIG_DEST/xdg-desktop-portal"
cp -rf "$REPO_PATH/dotconfig/xdg-desktop-portal"/* "$CONFIG_DEST/xdg-desktop-portal/"

# Copy rofi-collection module
echo "󰍉 Copying rofi-collection module..."
mkdir -p "$CONFIG_DEST/rofi"
cp -rf "$REPO_PATH/modules/rofi-collection"/files/* "$CONFIG_DEST/rofi/" 2>/dev/null || true

# Install rofi-collection fonts
echo "󰛖 Installing rofi fonts..."
FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"
cp -rf "$REPO_PATH/modules/rofi-collection/fonts"/* "$FONT_DIR/"
fc-cache -f "$FONT_DIR"

# Adds personal rofi themes
echo "󰏘 Applying custom Rofi themes..."
ROFI_CUSTOM_PATH="$REPO_PATH/dotconfig/rofi"
if [ -d "$ROFI_CUSTOM_PATH" ]; then
    cp -rf "$ROFI_CUSTOM_PATH"/* "$CONFIG_DEST/rofi/"
fi

# Create symbolic links for binary files (bin -> ~/.local/bin)
echo "󰌹 Creating symbolic links for binaries..."
for file in "$REPO_PATH/bin"/*; do
    [ -f "$file" ] && ln -sf "$file" "$BIN_FILES_PATH/$(basename "$file")"
done

if [ "$SKIP_THEME" = false ]; then
    # Apply default theme
    echo "󰏘 Setting up colors..."
    "$REPO_PATH/bin/wallust-theme-manager.sh" --restore-default --notify 2>/dev/null || true

    # Copy color templates
    echo "󰆐 Copying color templates to wallust cache..."
    WALLUST_REPO_COLORS="$REPO_PATH/dotconfig/wallust/colors"
    if [ -d "$WALLUST_REPO_COLORS" ]; then
        cp "$WALLUST_REPO_COLORS"/* "$HOME/.cache/wallust/colors/" 2>/dev/null || true
    fi
fi

echo "󰉋 Repository path: $REPO_PATH"
echo "󱂵 Home directory:  $HOME"

echo "󰑓 Reloading Hyprpm..."
hyprpm reload

echo "󰑓 Reloading Hyprland..."
hyprctl reload

echo "󰄬 Installation complete!"
