#!/bin/bash

# 1. INJECT WALLUST CACHE
source ~/.cache/wallust/colors/colors-rofi-sh.conf

CONFIG="$HOME/.config/hypr/keybindings.conf"
THEME="$HOME/.config/rofi/launchers/type-2/style-1.rasi"

if [ ! -f "$CONFIG" ]; then
    echo "Error: Config file not found at $CONFIG"
    exit 1
fi

# 2. PASS VARIABLES TO AWK
awk -v accent="$color15" -v muted="$color8" -F',' '
/^(bind|bindd|binde|bindm|bindl)/ {
    # 1. INITIAL CLEANUP
    line=$0;
    
    type=$1;
    sub(/^[ \t]*/, "", type);
    sub(/[ \t]*=.*$/, "", type); 

    sub(/^[ \t]*bind[a-z]*[ \t]*=[ \t]*/, "", line);

    split(line, args, ",");

    # 2. PROCESS MODIFIERS AND KEYS
    mods = args[1]; gsub(/^[ \t]+|[ \t]+$/, "", mods);
    key  = args[2]; gsub(/^[ \t]+|[ \t]+$/, "", key);
    
    gsub(/\$mainMod/, "SUPER", mods);
    if (mods == "") mods = "DIRECT"; 

    # 3. TEXT LOGIC (BIND / BINDD)
    display_text = "";

    if (type == "bindd") {
        desc = args[3]; gsub(/^[ \t]+|[ \t]+$/, "", desc);
        display_text = desc;
    } else {
        cmd = args[3]; gsub(/^[ \t]+|[ \t]+$/, "", cmd);
        arg = args[4]; gsub(/^[ \t]+|[ \t]+$/, "", arg);

        gsub(/exec/, "", cmd);
        gsub(/dispatch/, "", cmd);
        gsub(/signal/, "", cmd);
        gsub(/pass/, "", cmd);
        
        if (arg != "") {
            display_text = cmd " " arg;
        } else {
            display_text = cmd;
        }
    }

    gsub(/^[ \t]+|[ \t]+$/, "", display_text);

    # 4. ICONS 
    if (mods != "" && key != "" && display_text != "") {
        icon = " " 
        
        if (display_text ~ /Terminal|Alacritty|Kitty|Foot/) icon = " "
        if (display_text ~ /Browser|Firefox|Chrome|Brave|Edge/) icon = " "
        if (display_text ~ /File|Thunar|Dolphin/) icon = " "
        if (display_text ~ /Launcher|Apps|Rofi|Wofi/) icon = " "
        if (display_text ~ /Window|Close|Float|Tile|Pin|Opaque|Kill/) icon = " "
        if (display_text ~ /Workspace|Scratchpad/) icon = " "
        if (display_text ~ /Move|Split|Pseudo|Rotate|Swap/) icon = " "
        if (display_text ~ /Resize/) icon = " "
        if (display_text ~ /Volume|Audio|Mute/) icon = " "
        if (display_text ~ /Brightness|Light/) icon = " "
        if (display_text ~ /Screenshot|Capture/) icon = " "
        if (display_text ~ /Color|Picker/) icon = " "
        if (display_text ~ /Clipboard|Clip/) icon = " "
        if (display_text ~ /Guide|Help/) icon = " "
        if (display_text ~ /Exit|Logout/) icon = " "

        # 5. PRINT DYNAMIC PANGO FORMAT
        printf "<b><span color=\"%s\">%-18s</span></b>   <span color=\"%s\">%s</span>  <span size=\"small\">%s</span>\n", \
        accent, (mods == "DIRECT" ? key : mods " + " key), muted, icon, display_text
    }
}' "$CONFIG" | \
rofi -dmenu \
    -i \
    -markup-rows \
    -p "Keybindings" \
    -theme "$THEME" \
    -theme-str 'window {width: 900px;} listview {columns: 1;}' \
    -theme-str "element selected.normal { border: 0px 0px 0px 4px; border-color: ${color2}; background-color: ${color0}; }"