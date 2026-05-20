#!/usr/bin/env bash

REPO_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSHRC_SRC="$REPO_PATH/dotconfig/zsh/.zshrc"
ZSHRC_DEST="$HOME/.zshrc"

echo "󰄛 Zsh setup"

if [ -f "$ZSHRC_DEST" ]; then
    read -r -p "  ~/.zshrc already exists. Overwrite? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { echo "  Skipped."; exit 0; }
    cp "$ZSHRC_DEST" "${ZSHRC_DEST}.bak"
    echo "  Backup saved to ~/.zshrc.bak"
fi

cp "$ZSHRC_SRC" "$ZSHRC_DEST"
echo "  ~/.zshrc installed."

if [ "$SHELL" != "$(which zsh)" ]; then
    read -r -p "  Set zsh as default shell? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] && chsh -s "$(which zsh)" && echo "  Default shell changed to zsh."
fi

echo "󰄬 Done. Restart your terminal or run: source ~/.zshrc"
