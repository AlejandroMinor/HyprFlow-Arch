#!/usr/bin/env bash
# Prints an fzf --color value from the current wallust palette, so the
# pickers (theme-picker.sh, pet-picker.sh) follow the theme like everything
# else. Falls back to Tokyo Night when wallust has not written a palette yet.
#
#   fzf --color="$(fzf-colors.sh)"

PALETTE="${WALLUST_SH_PALETTE:-$HOME/.cache/wallust/colors/colors-rofi-sh.conf}"

foreground='#c0caf5' color0='#1a1b26' color1='#f7768e' color4='#7aa2f7' color5='#bb9af7' color8='#565f89'
# shellcheck source=/dev/null
[ -r "$PALETTE" ] && . "$PALETTE"

# bg:-1 keeps the terminal's own (translucent) background.
printf 'bg:-1,fg:%s,bg+:%s,fg+:%s,hl:%s,hl+:%s,prompt:%s,pointer:%s,border:%s\n' \
    "$foreground" "$color0" "$foreground" "$color4" "$color5" "$color4" "$color1" "$color8"
