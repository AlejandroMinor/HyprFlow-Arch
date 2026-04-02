#!/usr/bin/env python3
import subprocess
import json
peripherals_info = {}

def get_percentage(command: str, args: str = None) -> dict:
    cmd_list = [command]
    if args:
        cmd_list.append(args)
    result = subprocess.run(cmd_list, capture_output=True, text=True)
    
    if result.returncode == 0:
        try:
            data = json.loads(result.stdout)
            return data 
        except json.JSONDecodeError:
            return {"text": "Error", "class": "error", "percentage": 0}
            
    return {"text": "Not Found", "class": "not-found", "percentage": 0}

def main():
    devices = {
        "keyboard": ("peripherals_battery.sh", "keyboard"),
        "mouse": ("peripherals_battery.sh", "mouse"),
        "g733": ("g733_battery.sh", None),
        "trackpad": ("trackpad-battery", None)
    }
    
    for device_name, (command, args) in devices.items():
        peripherals_info[device_name] = get_percentage(command, args)

    for device_name, info in peripherals_info.items():
        if info.get("class") == "critical" or info.get("class") == "warning":
            alert = {
                "class": info.get("class"),
                "device": device_name,
                "percent": info.get("percentage", 0)
            }
            print(json.dumps(alert))
            return
        
    alert = {
        "class": "fine",
        "device": "all",
        "percent": 100
    }
    print(json.dumps(alert))

if __name__ == "__main__":
    main()
