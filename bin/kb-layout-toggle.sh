#!/usr/bin/env bash
CURRENT=$(hyprctl getoption input:kb_layout | awk '/str:/ {print $2}')

if [ "$CURRENT" = "latam" ]; then
    hyprctl keyword input:kb_layout us
else
    hyprctl keyword input:kb_layout latam
fi
