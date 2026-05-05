#!/usr/bin/env python3
import json
import subprocess
import os
import sys

TEMPLATE_DIR = os.path.expanduser("~/.config/hypr/templates/")
os.makedirs(TEMPLATE_DIR, exist_ok=True)

def get_full_command(pid):
    try:
        with open(f"/proc/{pid}/cmdline", 'r') as f:
            parts = f.read().split('\0')
            parts = [p for p in parts if p.strip()]
            return ' '.join(parts)
    except (FileNotFoundError, PermissionError):
        return None

def get_monitor_offsets():
    monitors = json.loads(subprocess.check_output(["hyprctl", "monitors", "-j"]))
    return {
        m['id']: {
            'x': m['x'],
            'y': m['y'],
            'reserved_top': m['reserved'][1]
        } for m in monitors
    }

def save_template(name):
    clients = json.loads(subprocess.check_output(["hyprctl", "clients", "-j"]))
    monitor_offsets = get_monitor_offsets()
    session_data = []

    IGNORED = {"waybar", "rofi", "swaync", ""}

    for client in clients:
        cls = client['class']
        if cls in IGNORED:
            continue

        cmd = get_full_command(client['pid'])
        if cmd:
            monitor_id = client.get('monitor', 0)
            offset = monitor_offsets.get(monitor_id, {'x': 0, 'y': 0, 'reserved_top': 0})
            at = client.get('at', [0, 0])
            relative_x = at[0] - offset['x']
            relative_y = at[1] - offset['y'] - offset['reserved_top']

            session_data.append({
                "workspace": client['workspace']['id'],
                "command": cmd,
                "class": cls,
                "initialClass": client.get('initialClass', cls),
                "floating": client.get('floating', False),
                "at": [relative_x, relative_y],
                "size": client.get('size', [800, 600])
            })

    file_path = os.path.join(TEMPLATE_DIR, f"{name}.json")
    with open(file_path, "w") as f:
        json.dump(session_data, f, indent=4)
    print(f"Layout '{name}' saved to {file_path}")

if __name__ == "__main__":
    tag = sys.argv[1] if len(sys.argv) > 1 else "default"
    save_template(tag)