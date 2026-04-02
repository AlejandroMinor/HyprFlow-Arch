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
    peripherals_info["keyboard"] = get_percentage("peripherals_battery.sh", "keyboard")
    peripherals_info["mouse"] = get_percentage("peripherals_battery.sh", "mouse")
    peripherals_info["g733"] = get_percentage("g733_battery.sh")
    peripherals_info["trackpad"] = get_percentage("trackpad-battery")


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
