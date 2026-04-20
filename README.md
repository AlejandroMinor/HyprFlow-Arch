# HyprFlow-Arch

Configuración completa de **Hyprland + Arch Linux** optimizada para productividad técnica con soporte para múltiples monitores, periféricos Logitech/Apple y tematización dinámica automatizada.

## Características Principales

- **Instalación automatizada** — un script copia configs, crea symlinks y aplica el tema base
- **Tematización dinámica** — paletas de color generadas automáticamente con `wallust` al cambiar wallpaper
- **Gestión de 4 monitores** — mapeo lógico automático vía `monitors.sh`, layout configurable
- **Batería de periféricos en Waybar** — mouse, teclado, trackpad y headset en tiempo real
- **Módulos de estado** — VPN, cámara, micrófono, audio y notificaciones DND integrados
- **Soporte DisplayLink** — compatibilidad con dock Dell D6000

## Tabla de Contenidos

- [Vista Previa](#vista-previa)
- [Hardware y Periféricos](#hardware-y-periféricos)
- [Instalación](#instalación)
- [Scripts Incluidos](#scripts-incluidos)
- [Post-Instalación](#post-instalación)
- [Plugins de Hyprland](#plugins-de-hyprland)
- [Estructura del Proyecto](#estructura-del-proyecto)
- [Tips](#tips)

## Vista Previa



## Hardware y Periféricos

Setup diseñado para los siguientes periféricos, con monitoreo de batería integrado:

| Periférico | Modelo |
|------------|--------|
| Mouse | Logitech MX Master 3S |
| Teclado | Logitech MX Keys S |
| Trackpad | Apple Magic Trackpad |
| Dock | Dell D6000 (DisplayLink) |

### Distribución de Monitores (4 pantallas)

El mapeo lógico se define en `monitors_ids.conf` (auto-generado). El layout actual de izquierda a derecha:

| Posición | Monitor | Resolución |
|----------|---------|------------|
| 1 | AOC | 1080p |
| 2 | NZXT (Principal) | 1440p @ 120Hz |
| 3 | ASUS | 1080p |
| 4 | ThinkPad (laptop) | 1080p |

## Instalación

### 1. Instalar dependencias

**Repositorios oficiales:**
```bash
sudo pacman -S cpio cmake fzf rtkit hyprland waybar yazi kitty awww brightnessctl playerctl pipewire wireplumber pipewire-pulse pavucontrol network-manager-applet upower openconnect jq pacman-contrib swaync hyprshot rofi-wayland ttf-jetbrains-mono-nerd noto-fonts-cjk wl-clipboard satty gnu-free-fonts gnome-themes-extra xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-hyprland gnome-disk-utility polkit-gnome
```

**AUR (requiere `yay` u otro helper):**
```bash
yay -S wlogout eww-git displaylink evdi-dkms-git waypaper-git warp-terminal-bin wallust headsetcontrol bibata-cursor-theme-bin
```

### 2. Clonar e instalar

Este repositorio usa **submódulos Git** (temas de Rofi, trackpad-battery, sinkswitch). Clona con `--recursive`:

```bash
git clone --recursive https://github.com/AlejandroMinor/HyprFlow-Arch.git
cd HyprFlow-Arch
bash install.sh
```

Si ya clonaste sin `--recursive`:
```bash
git submodule update --init --recursive
```

El script de instalación se encarga de:
- Dar permisos de ejecución a todos los scripts `.sh` y `.py`
- Copiar configuración a `~/.config`
- Crear symlinks de los binarios en `~/.local/bin`
- Aplicar la paleta de colores por defecto
- Recargar Hyprland y los plugins

### 3. Primeros pasos

Ejecuta `help-binds` para ver todos los atajos de teclado disponibles:

```bash
help-binds
```

## Scripts Incluidos

Todos los scripts en `bin/` quedan disponibles globalmente en `~/.local/bin` tras la instalación.

| Script | Descripción |
|--------|-------------|
| `wallust-theme-manager.sh` | Genera paletas de color dinámicas y aplica temas |
| `monitors.sh` | Detecta monitores y crea el mapeo en `monitors_ids.conf` |
| `help-binds.sh` | Muestra todos los atajos de teclado en interfaz visual |
| `mute_indicator.sh` | Indicador de estado del micrófono en Waybar |
| `swaync-dnd.sh` | Control de Do Not Disturb en SwayNC |
| `vpn_status.sh` | Estado de conexión VPN en Waybar |
| `peripherals_battery.sh` | Batería de periféricos en Waybar |
| `battery_alert.py` | Alerta de batería baja del sistema |
| `camera_status.py` | Indicador de cámara en uso |
| `g733_battery.sh` | Batería del headset Logitech G733 |
| `trackpad-battery` | Batería del Apple Magic Trackpad |
| `sinkswitch` | Cambio rápido entre dispositivos de audio |

**Submódulos incluidos:**
- `modules/rofi-collection` — colección de temas, applets y launchers para Rofi
- `modules/apple-magic-trackpad-battery` — script de batería del trackpad
- `modules/sinkswitch` — utilidad de cambio de audio output

## Post-Instalación

### Tema oscuro
Si quieres forzar colores oscuros para apps GTK:

```bash
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
gsettings set org.gnome.desktop.interface icon-theme 'Adwaita'
```

### Magic Trackpad (opcional)

Para leer correctamente el estado de batería del trackpad, crea la regla udev:

```bash
echo 'SUBSYSTEM=="hidraw", DRIVERS=="magicmouse", MODE="0660", GROUP="input"' | \
  sudo tee /etc/udev/rules.d/99-magictrackpad.rules && \
  sudo udevadm control --reload-rules && \
  sudo udevadm trigger
```

### Tematización con Waypaper (recomendado)

En `~/.config/waypaper/config.ini`, activa `zen_mode` y el `post_command` para regenerar la paleta al cambiar wallpaper:

```ini
[Settings]
backend = awww
fill = fill
zen_mode = True
post_command = bash -c "$HOME/HyprFlow-Arch/bin/wallust-theme-manager.sh --generate-palette --notify"
```

Para restaurar la paleta por defecto manualmente:

```bash
wallust cs ~/HyprFlow-Arch/wallust/themes/minor-default.json
~/HyprFlow-Arch/bin/wallust-theme-manager.sh --restore-default --notify
```

### Detección de monitores

Si agregas o cambias monitores, regenera el mapeo lógico:

```bash
monitors.sh
```

Si se presenta algún problema con Waybar, revisa `monitors_ids.conf` y ajusta los IDs manualmente. 
Tambien puedes reiniciar hyprland para que recargue la configuración:

```bash
hyprctl reload
```

### Dell D6000 / DisplayLink

```bash
sudo systemctl enable --now displaylink.service
```

## Plugins de Hyprland

Instala y gestiona plugins con `hyprpm`:

```bash
hyprpm update
hyprpm add https://github.com/hyprwm/hyprland-plugins
hyprpm enable <plugin-name>
```

Plugins actualmente activos:

| Plugin | Descripción |
|--------|-------------|
| `hyprfocus` | Animación de foco de ventanas mejorada |
| `hyprwinwrap` | Embebe aplicaciones directamente en el fondo de escritorio |

## Estructura del Proyecto

```
HyprFlow-Arch/
├── bin/                          # Scripts ejecutables (symlinkeados a ~/.local/bin)
│   ├── wallust-theme-manager.sh
│   ├── monitors.sh
│   ├── help-binds.sh
│   ├── session-manager/          # Guardar/restaurar layout de ventanas
│   └── ...
│
├── dotconfig/                    # Configuración (~/.config)
│   ├── hypr/
│   │   ├── hyprland.conf
│   │   ├── keybindings.conf
│   │   ├── monitors.conf         # Layout físico
│   │   ├── monitors_ids.conf     # Mapeo lógico (auto-generado)
│   │   ├── animations.conf
│   │   └── gestures.conf
│   ├── wallust/                  # Config de wallust y paletas
│   ├── waybar/
│   ├── rofi/
│   ├── kitty/
│   ├── eww/
│   └── wlogout/
│
├── modules/                      # Submódulos Git
│   ├── rofi-collection/
│   ├── apple-magic-trackpad-battery/
│   └── sinkswitch/
│
├── install.sh
└── README.md
```

## Tips

- **Waybar + monitores:** Si Waybar no aparece bien, revisa `dotconfig/hypr/monitors_ids.conf` y ajusta los IDs. El script `monitors.sh` lo resuelve en la mayoría de casos, pero con ciertos docks puede requerir ajuste manual en `dotconfig/waybar/config`.
- **Sesiones:** `session-manager/save.sh` guarda el layout actual; `restore.sh` lo recupera. Ambos están disponibles como keybindings.
- **Permisos:** Si un script no ejecuta, `chmod +x nombre_script`. El `install.sh` los asigna automáticamente.
