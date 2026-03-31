#!/bin/bash

if pgrep -x "openconnect" > /dev/null || pgrep -x "vpnc" > /dev/null; then
    echo '{"text":"󰒃","class":"vpn-status-active"}'
else
    echo '{"text":"󰒃","class":"vpn-status-warning"}'
fi
