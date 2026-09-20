#!/usr/bin/env python3
import os
import json

def check_camera():

    video_devices = {f"/dev/{d}" for d in os.listdir("/dev") if d.startswith("video")}
    is_active = False
    active_device = ""

    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        fd_dir = f"/proc/{pid}/fd"
        try:
            fds = os.listdir(fd_dir)
        except (FileNotFoundError, PermissionError, ProcessLookupError):
            continue
        for fd in fds:
            try:
                target = os.readlink(f"{fd_dir}/{fd}")
            except OSError:
                continue
            if target in video_devices:
                is_active = True
                active_device = target
                break
        if is_active:
            break

    if is_active:

        return {
            "text": " ", 
            "class": "active", 
            "tooltip": f"Cámara en uso: {active_device}"
        }
    else:
        return {"text": "", "class": "inactive"}

if __name__ == "__main__":
    print(json.dumps(check_camera()))
