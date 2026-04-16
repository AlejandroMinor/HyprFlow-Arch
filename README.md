# HyprFlow-Arch

Configuración completa de **Hyprland + Arch Linux** optimizada para productividad técnica avanzada con soporte para múltiples monitores, periféricos de lujo y automatización inteligente.

### Características Principales

- ⚙️ **Configuración completa lista para usar** - Instalación automatizada con un script
- 🎨 **Tematización dinámica** - Generación automática de paletas con `wallust`
- 📊 **Gestor de monitores avanzado** - Mapeo automático de 4 pantallas  
- 🔋 **Monitoreo de batería integrado** - Batería de mouse, trackpad, teclado y headset en Waybar
- 🎯 **Múltiples aplicaciones y módulos** - Launcher de Rofi personalizado, controles de audio, status VPN, etc.
- 🔌 **Soporte para periféricos** - Optimizado para Magic Trackpad, Logitech MX Master, Dell D6000 y más

## Tabla de Contenidos

- [Hardware & Periféricos](#hardware--periféricos)
- [Instalación Rápida](#instalación-rápida)
- [Clonación del Repositorio](#clonación-del-repositorio)
- [Dependencias](#dependencias)
- [Scripts y Binarios Incluidos](#scripts-y-binarios-incluidos)
- [Post-Instalación y Configuración](#post-instalación-y-configuración)
- [Hyprland Plugins](#hyprland-plugins)
- [Estructura del Proyecto](#estructura-del-proyecto)

## Hardware & Periféricos

Este setup está diseñado para los siguientes periféricos, con gestión de batería integrada en Waybar:

* **Mouse:** Logitech MX Master 3S.
* **Teclado:** Logitech MX Keys S.
* **Trackpad:** Apple Magic Trackpad (vía `magic-trackpad-battery-git`).
* **Dock:** Dell D6000 (Soporte DisplayLink).

### Gestión de Monitores (4 Pantallas)

El mapeo lógico de hardware se define en `monitors_ids.conf`, mientras que la disposición física se gestiona en `monitors.conf`. El layout actual de izquierda a derecha es:

1. **AOC** ($AOC - 1080p).
2. **NZXT** (Principal - 1440p @ 120Hz).
3. **ASUS** ($ASUS - 1080p).
4. **THINKPAD** (Laptop - 1080p).

## Instalación Rápida

### Primero instala las dependencias

```bash
sudo pacman -S cpio cmake hyprland waybar yazi kitty awww brightnessctl playerctl wireplumber pavucontrol network-manager-applet upower openconnect jq pacman-contrib swaync hyprshot rofi-wayland ttf-jetbrains-mono-nerd noto-fonts-cjk wl-clipboard satty gnu-free-fonts
```

```bash
yay -S wlogout eww-git displaylink evdi-dkms-git waypaper-git warp-terminal-bin wallust headsetcontrol
```

### Luego instala esta configuración:

```bash
git clone --recursive https://github.com/AlejandroMinor/HyprFlow-Arch.git
cd HyprFlow-Arch
chmod +x install.sh
bash install.sh
```

El script se encargará de:
- ✅ Dar permisos de ejecución a todos los scripts `.sh` y `.py`
- ✅ Copiar configuración a `~/.config`
- ✅ Crear enlaces simbólicos de los binarios en `~/.local/bin`
- ✅ Aplicar la paleta de colores por defecto
- ✅ Recargar Hyprland y los plugins

### Después de la instalación:

1. **Configurar periféricos** si es necesario (ver [Post-Instalación](#post-instalación-y-configuración))
2. **Recargar Hyprland:** `hyprctl reload`

## Clonación del Repositorio

Este proyecto utiliza **submódulos de Git** para gestionar dependencias externas (como la colección de temas de Rofi). Es importante clonar el repositorio con la opción `--recursive`:

```bash
git clone --recursive https://github.com/AlejandroMinor/HyprFlow-Arch.git
cd HyprFlow-Arch
```

Si ya tienes el repositorio clonado sin los submódulos, actualízalos con:

```bash
git submodule update --init --recursive
```

## Dependencias

* **Rofi:** Temas basados en la colección de adi1090x/rofi (incluido como submódulo).
* **Tematización:** Soporte para colores dinámicos con `wallust`.

### Instalación Completa (Repos Oficiales)
```bash
sudo pacman -S cpio cmake hyprland waybar yazi kitty awww brightnessctl playerctl wireplumber pavucontrol network-manager-applet upower openconnect jq pacman-contrib swaync hyprshot rofi-wayland ttf-jetbrains-mono-nerd noto-fonts-cjk wl-clipboard satty gnu-free-fonts
```

### Instalación Completa (AUR)
```bash
yay -S wlogout eww-git displaylink evdi-dkms-git waypaper-git warp-terminal-bin wallust headsetcontrol
```

## Scripts y Binarios Incluidos

Todos los scripts en `bin/` están disponibles en `~/.local/bin` después de la instalación y pueden ser ejecutados desde cualquier lugar.

| Script | Descripción |
|--------|-------------|
| `wallust-theme-manager.sh` | Gestor de temas - genera paletas de colores dinámicas y aplica temas |
| `monitors.sh` | Detecta automáticamente los monitores y crea el mapeo en `monitors_ids.conf` |
| `help-binds.sh` | Muestra todos los atajos de teclado de Hyprland en una interfaz visual |
| `mute_indicator.sh` | Indicador de estado de micrófono en Waybar |
| `swaync-dnd.sh` | Control de "Do Not Disturb" (DND) en SwayNC |
| `vpn_status.sh` | Muestra el estado de conexión VPN en Waybar |
| `peripherals_battery.sh` | Monitorea y muestra la batería de periféricos en Waybar |
| `battery_alert.py` | Alerta de batería baja del sistema |
| `camera_status.py` | Indicador de estado de cámara en uso |
| `g733_battery.sh` | Muestra la batería del headset Logitech G733 |
| `trackpad-battery` | Monitorea la batería del Magic Trackpad |
| `sinkswitch` | Cambiar rápidamente entre dispositivos de audio (sinks) |

**Módulos incluidos (submódulos):**
- `rofi-collection` - Colección completa de temas, applets y launchers para Rofi
- `apple-magic-trackpad-battery` - Script especializado para mostrar batería del trackpad
- `sinkswitch` - Utilidad para cambiar outputs de audio

## Post-Instalación y Configuración

### 1. Configuración de Magic Trackpad (Opcional - solo si lo usas)
Para que el Magic Trackpad se pueda leer correctamente, ejecuta el siguiente comando para crear la regla udev:

```bash
echo 'SUBSYSTEM=="hidraw", DRIVERS=="magicmouse", MODE="0660", GROUP="input"' | sudo tee /etc/udev/rules.d/99-magictrackpad.rules && sudo udevadm control --reload-rules && sudo udevadm trigger
```

### 2. Inicialización de Temas (Opcional)
El script de instalación ya genera automáticamente la paleta por defecto y aplica los temas. Si necesitas restaurar manualmente los valores por defecto:

```bash
wallust cs ~/HyprFlow-Arch/wallust/themes/minor-default.json
~/HyprFlow-Arch/bin/wallust-theme-manager.sh --restore-default --notify
```

### 3. Configuración de Waypaper (Recomendado)
En `~/.config/waypaper/config.ini`, activa el `zen_mode` y el `post_command` para generar la paleta automáticamente al cambiar el fondo:

```ini
[Settings]
backend = swww
fill = fill
zen_mode = True
post_command = bash -c "$HOME/HyprFlow-Arch/bin/wallust-theme-manager.sh --generate-palette --notify"
```

### 4. Detección automática de monitores
Para detectar automáticamente tus monitores y crear el mapeo lógico:

```bash
~/HyprFlow-Arch/bin/monitors.sh
```

## Estructura del Proyecto

```
HyprFlow-Arch/
├── bin/                          # Scripts y binarios ejecutables
│   ├── wallust-theme-manager.sh  # Gestor de temas (principal)
│   ├── monitors.sh               # Detección automática de monitores
│   ├── help-binds.sh             # Visualizador de atajos
│   ├── session-manager/          # Gestor de sesiones (save/restore/load)
│   └── [otros scripts...]        # Scripts de estado y controles
│
├── dotconfig/                    # Archivos de configuración (~/.config)
│   ├── hypr/                     # Configuración de Hyprland
│   │   ├── hyprland.conf         # Configuración principal
│   │   ├── keybindings.conf      # Atajos de teclado
│   │   ├── monitors.conf         # Layout de monitores
│   │   ├── monitors_ids.conf     # Mapeo lógico (auto-generado)
│   │   ├── animations.conf       # Animaciones
│   │   └── gestures.conf         # Gestos del touchpad
│   ├── wallust/                  # Configuración de temas
│   │   ├── wallust.toml          # Config de wallust
│   │   ├── colors/               # Paletas de colores generadas
│   │   └── templates/            # Plantillas para themes
│   ├── rofi/                     # Configuración de Rofi
│   ├── waybar/                   # Barra de estado
│   └── wlogout/                  # Menú de apagado
│
├── modules/                      # Submódulos de Git (dependencias externas)
│   ├── rofi-collection/          # Colección de temas de Rofi
│   ├── apple-magic-trackpad-battery/  # Script de batería del trackpad
│   └── sinkswitch/               # Utilidad de audio
│
├── install.sh                    # Script automatizado de instalación
└── README.md                     # Este archivo
```

## Hyprland Plugins (hyprpm)

El repositorio oficial de plugins para `hyprpm` es [hyprwm/hyprland-plugins](https://github.com/hyprwm/hyprland-plugins).

Flujo recomendado:

```bash
hyprpm update
hyprpm add https://github.com/hyprwm/hyprland-plugins
hyprpm list
hyprpm enable <plugin-name>
hyprpm update
```

Si quieres verificar qué plugins quedaron instalados antes de activarlos, usa:

```bash
hyprpm list
```

Plugins actualmente activos:

| Plugin | Descripción |
|--------|-------------|
| **hyprfocus** | Animación de transición y foco de ventanas mejorada |
| **hyprwinwrap** | Permite embeber aplicaciones (como terminales de monitoreo) directamente en el fondo de escritorio |

### Configuración de DisplayLink (para el Dock Dell D6000)

Si usas el Dell D6000 con Hyprland, habilita el servicio:

```bash
sudo systemctl enable --now displaylink.service
```

## Primeros Pasos Después de Instalar

**Te recomendamos ejecutar primero `help-binds`** para ver todos los atajos de teclado disponibles y familiarizarte con las funcionalidades principales:

```bash
help-binds
```

Esto abrirá una interfaz visual donde podrás explorar todos los keybindings configurados.

## Notas y Tips

- **Atajos de teclado:** Muchos de los binarios pueden ejecutarse directamente desde atajos. Usa `help-binds` para ver todos los keybindings disponibles
- **Temas:** Cambia de tema con `wallust cs <tema.json>` y luego `wallust-theme-manager.sh --restore-default` (también asignado a atajos)
- **Sesiones:** Usa `session-manager/save.sh` para guardar el layout actual, `restore.sh` para recuperarlo (disponibles en keybindings)
- **Audio:** Usa `sinkswitch` para cambiar rápidamente entre dispositivos de audio (también en atajos)
- **Monitores:** Si agregas o cambias monitores, ejecuta `monitors.sh` nuevamente
- **Permisos:** Los scripts `.sh` requieren permisos de ejecución. El `install.sh` los asigna automáticamente
