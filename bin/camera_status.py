#!/usr/bin/env python3
import os
import json
import subprocess

def check_camera():

    video_devices = [f"/dev/{d}" for d in os.listdir("/dev") if d.startswith("video")]
    is_active = False
    active_device = ""

    for dev in video_devices:
        try:
            result = subprocess.run(
                ["fuser", dev], 
                stdout=subprocess.DEVNULL, 
                stderr=subprocess.DEVNULL
            )
            if result.returncode == 0:
                is_active = True
                active_device = dev
                break
        except Exception:
            continue
                
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
