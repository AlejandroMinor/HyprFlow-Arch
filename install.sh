#!/usr/bin/env bash

REPO_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_FILES_PATH="$HOME/.local/bin"
CONFIG_DEST="$HOME/.config"

echo "🚀 Installing HyprFlow-Arch..."

mkdir -p "$BIN_FILES_PATH"
mkdir -p "$CONFIG_DEST"

# Copy configuration files (dotconfig -> ~/.config)
echo "📁 Copying configuration files..."
cp -rf "$REPO_PATH/dotconfig"/* "$CONFIG_DEST/"

# Copy rofi-collection module
echo "📁 Copying rofi-collection module..."
mkdir -p "$CONFIG_DEST/rofi"
cp -rf "$REPO_PATH/modules/rofi-collection"/files/* "$CONFIG_DEST/rofi/" 2>/dev/null || true

# 📁 Adds personal rofi themes
echo "🎨 Applying custom Rofi themes..."
ROFI_CUSTOM_PATH="$REPO_PATH/dotconfig/rofi"
if [ -d "$ROFI_CUSTOM_PATH" ]; then
    cp -rf "$ROFI_CUSTOM_PATH"/* "$CONFIG_DEST/rofi/"
fi

# Create symbolic links for binary files (bin -> ~/.local/bin)
echo "⚙️  Creating symbolic links for binaries..."
for file in "$REPO_PATH/bin"/*; do
    ln -sf "$file" "$BIN_FILES_PATH/$(basename "$file")"
done

# Apply default theme 
echo "🎨 Setting up colors..."
"$REPO_PATH/bin/wallust-theme-manager.sh" --restore-default --notify 2>/dev/null || true

# Copy color templates
echo "📁 Copying color templates to wallust cache..."
WALLUST_REPO_COLORS="$REPO_PATH/dotconfig/wallust/colors"
if [ -d "$WALLUST_REPO_COLORS" ]; then
    cp "$WALLUST_REPO_COLORS"/* "$HOME/.cache/wallust/colors/" 2>/dev/null || true
fi

echo "📂 Repository path: $REPO_PATH"
echo "Home directory: $HOME"

echo "Reload Hyprpm ..."
hyprpm reload

echo "🔄 Reloading Hyprland"
hyprctl reload

echo "✅ Installation complete!"