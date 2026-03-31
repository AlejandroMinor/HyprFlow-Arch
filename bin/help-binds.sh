#!/bin/bash

# 1. INYECTAR LA CACHÉ DE PYWAL
source ~/.cache/wallust/colors/colors-rofi-sh.conf

CONFIG="$HOME/.config/hypr/keybindings.conf"
THEME="$HOME/.config/rofi/launchers/type-2/style-1.rasi"

if [ ! -f "$CONFIG" ]; then
    echo "Error: No se encuentra el archivo de configuración en $CONFIG"
    exit 1
fi

# 2. PASAR VARIABLES A AWK
awk -v accent="$color15" -v muted="$color8" -F',' '
/^(bind|bindd|binde|bindm|bindl)/ {
    # 1. LIMPIEZA INICIAL
    line=$0;
    
    type=$1;
    sub(/^[ \t]*/, "", type);
    sub(/[ \t]*=.*$/, "", type); 

    sub(/^[ \t]*bind[a-z]*[ \t]*=[ \t]*/, "", line);

    split(line, args, ",");

    # 2. PROCESAR MODIFICADORES Y TECLAS
    mods = args[1]; gsub(/^[ \t]+|[ \t]+$/, "", mods);
    key  = args[2]; gsub(/^[ \t]+|[ \t]+$/, "", key);
    
    gsub(/\$mainMod/, "SUPER", mods);
    if (mods == "") mods = "DIRECTO"; 

    # 3. LÓGICA DE TEXTO (BIND / BINDD)
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

    # 4. ICONOS 
    if (mods != "" && key != "" && display_text != "") {
        icon = " " 
        
        if (display_text ~ /Terminal|Alacritty|Kitty|Foot/) icon = " "
        if (display_text ~ /Navegador|Firefox|Chrome|Brave/) icon = " "
        if (display_text ~ /Archivos|File|Thunar|Dolphin/) icon = " "
        if (display_text ~ /Menú|Apps|Rofi|Wofi/) icon = " "
        if (display_text ~ /Ventana|Cerrar|Flotar|Tilear|Pin|Opaque|Kill/) icon = " "
        if (display_text ~ /Workspace|Escritorio|Mágico/) icon = " "
        if (display_text ~ /Mover|Split|Pseudo|Orientación|Swap/) icon = " "
        if (display_text ~ /Resize|Redimensionar/) icon = " "
        if (display_text ~ /Volumen|Audio|Mute/) icon = " "
        if (display_text ~ /Brillo|Luz/) icon = " "
        if (display_text ~ /Screenshot|Captura/) icon = " "
        if (display_text ~ /Color|Pipeta/) icon = " "
        if (display_text ~ /Portapapeles|Clip/) icon = " "
        if (display_text ~ /Guía|Ayuda/) icon = " "
        if (display_text ~ /Salir|Logout|Exit/) icon = " "

        # 5. IMPRIMIR FORMATO PANGO DINÁMICO
        printf "<b><span color=\"%s\">%-18s</span></b>   <span color=\"%s\">%s</span>  <span size=\"small\">%s</span>\n", \
        accent, (mods == "DIRECTO" ? key : mods " + " key), muted, icon, display_text
    }
}' "$CONFIG" | \
rofi -dmenu \
    -i \
    -markup-rows \
    -p "Atajos" \
    -theme "$THEME" \
    -theme-str 'window {width: 900px;} listview {columns: 1;}' \
    -theme-str "element selected.normal { border: 0px 0px 0px 4px; border-color: ${color2}; background-color: ${color0}; }"