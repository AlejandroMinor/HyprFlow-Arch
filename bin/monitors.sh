#!/bin/bash

PORT_AOC=$(hyprctl monitors all -j | jq -r '.[] | select(.description | contains("AOC 24B3HM")) | .name')
PORT_ASUS=$(hyprctl monitors all -j | jq -r '.[] | select(.description | contains("ASUS VA24E")) | .name')
PORT_NZXT=$(hyprctl monitors all -j | jq -r '.[] | select(.description | contains("NZXTCANVAS27Q")) | .name')
PORT_THINK=$(hyprctl monitors all -j | jq -r '.[] | select(.description | contains("Lenovo")) | .name')

cat <<EOF > ~/.config/hypr/monitors_ids.conf
\$AOC = $PORT_AOC
\$ASUS = $PORT_ASUS
\$NZXT = $PORT_NZXT
\$THINKPAD = $PORT_THINK
EOF


