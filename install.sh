#!/usr/bin/env bash

# ─────────────────────────────────────────
# VARIABLES
# ─────────────────────────────────────────

REPO_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_FILES_PATH="$HOME/.local/bin"
LIB_FILES_PATH="$HOME/.local/lib/hyprflow"
CONFIG_DEST="$HOME/.config"

WITH_DEPS=false
WITH_PLUGINS=false
WITH_ZSH=false

# Steps asked for on the command line. With none named, everything runs.
declare -A RUN=()
FULL_RUN=false

want() { [ -n "${RUN[$1]:-}" ]; }

usage() {
    cat <<'EOF'
usage: install.sh [step...] [option...]

With no step named, the full install runs.

Steps:
  check       report missing packages, submodules and plugins
  config      copy dotfiles, link scripts, install fonts
  theme       apply the default colour palette
  lockscreen  seed the avatar and build the hyprlock layout
  monitors    run the monitor wizard
  zsh         install .zshrc, and offer to make zsh your shell

Options:
  --with-deps      install the missing packages (pacman, then yay or paru)
  --with-plugins   install the missing Hyprland plugins (compiles, slow)
  --with-zsh       include the zsh step in a full run
  -h, --help       show this

Examples:
  install.sh                  full install
  install.sh config           push the dotfiles and nothing else
  install.sh check            just tell me what is missing
  install.sh config theme     dotfiles plus a recolour
EOF
}

for arg in "$@"; do
    case "$arg" in
        check|config|theme|lockscreen|monitors|zsh) RUN[$arg]=1 ;;
        --with-deps)    WITH_DEPS=true ;;
        --with-plugins) WITH_PLUGINS=true ;;
        --with-zsh)     WITH_ZSH=true ;;
        -h|--help)      usage; exit 0 ;;
        *)
            echo "install.sh: unknown argument '$arg'" >&2
            echo "try: install.sh --help" >&2
            exit 1 ;;
    esac
done

if [ ${#RUN[@]} -eq 0 ]; then
    FULL_RUN=true
    for step in check config theme lockscreen monitors; do RUN[$step]=1; done
    [ "$WITH_ZSH" = true ] && RUN[zsh]=1
fi

# One per progress() call in the functions each step runs. Keep in sync.
TOTAL_STEPS=0
want check      && TOTAL_STEPS=$((TOTAL_STEPS + 3))   # deps, submodules, plugins
want config     && TOTAL_STEPS=$((TOTAL_STEPS + 4))   # permissions, files, runcat, binaries
want theme      && TOTAL_STEPS=$((TOTAL_STEPS + 1))
want lockscreen && TOTAL_STEPS=$((TOTAL_STEPS + 1))
want monitors   && TOTAL_STEPS=$((TOTAL_STEPS + 1))
want zsh        && TOTAL_STEPS=$((TOTAL_STEPS + 1))
if want config || want theme || want lockscreen; then
    TOTAL_STEPS=$((TOTAL_STEPS + 1))                  # reload
fi
CURRENT_STEP=0

# Packages this config needs, in packages/: one per line, # starts a comment.
# Checked with `pacman -T`, which understands provides, so rofi satisfying
# rofi-wayland counts as installed.
read_packages() { sed 's/#.*//' "$REPO_PATH/packages/$1" | xargs; }
read -ra PACMAN_PKGS <<<"$(read_packages pacman.txt)"
read -ra AUR_PKGS    <<<"$(read_packages aur.txt)"

# Hyprland plugins, in the order they are reported.
PLUGIN_NAMES=(hymission hyprglass)
declare -A PLUGIN_REPOS=(
    [hymission]="https://github.com/gfhdhytghd/hymission"
    [hyprglass]="https://github.com/hyprnux/hyprglass"
)

# Whatever the checks could not resolve. final_report prints these at the end,
# where they are not lost behind a dozen progress bars.
MISSING_PACMAN=()
MISSING_AUR=()
MISSING_SUBMODULES=()
MISSING_PLUGINS=()      # not installed
DISABLED_PLUGINS=()     # installed, but not enabled
FAILED_STEPS=()         # "command to retry|what went wrong", for the final report

# ─────────────────────────────────────────
# PROGRESS BAR
# ─────────────────────────────────────────

progress() {
    local label="$1"
    CURRENT_STEP=$(( CURRENT_STEP + 1 ))
    local percent=$(( CURRENT_STEP * 100 / TOTAL_STEPS ))
    local width=36
    local filled=$(( CURRENT_STEP * width / TOTAL_STEPS ))
    [ "$percent" -gt 100 ] && percent=100
    [ "$filled" -gt "$width" ] && filled=$width
    local empty=$(( width - filled ))
    local filled_str="" empty_str="" i
    for ((i=0; i<filled; i++)); do filled_str+="█"; done
    for ((i=0; i<empty; i++)); do empty_str+="░"; done
    printf "\n\033[1;32m[%s\033[90m%s\033[1;32m]\033[0m \033[1m%3d%%\033[0m  \033[1;36m%s\033[0m\n\n" \
        "$filled_str" "$empty_str" "$percent" "$label"
}

# ─────────────────────────────────────────
# FUNCTIONS
# ─────────────────────────────────────────

# ── Dependencies ─────────────────────────

aur_helper() {
    command -v yay  >/dev/null 2>&1 && { echo yay;  return 0; }
    command -v paru >/dev/null 2>&1 && { echo paru; return 0; }
    return 1
}

check_dependencies() {
    progress "DEPENDENCIES"

    if ! command -v pacman >/dev/null 2>&1; then
        echo "󰀦 Not an Arch system, skipping the dependency check."
        return 0
    fi

    # pacman -T prints only the packages that are not satisfied.
    mapfile -t MISSING_PACMAN < <(pacman -T "${PACMAN_PKGS[@]}")
    mapfile -t MISSING_AUR    < <(pacman -T "${AUR_PKGS[@]}")

    if [ ${#MISSING_PACMAN[@]} -eq 0 ] && [ ${#MISSING_AUR[@]} -eq 0 ]; then
        echo "󰄬 All packages installed."
        return 0
    fi

    missing_banner

    # --with-deps installs first, whatever the steps, `check` alone included.
    if [ "$WITH_DEPS" = true ]; then
        install_dependencies
        [ ${#MISSING_PACMAN[@]} -eq 0 ] && [ ${#MISSING_AUR[@]} -eq 0 ] && return 0
        missing_banner
    fi

    # `check` on its own only reports; the steps after it would copy a config
    # onto a system that cannot fully run it, so those wait for an answer.
    if ! want config && ! want theme && ! want lockscreen && ! want monitors && ! want zsh; then
        [ "$WITH_DEPS" = true ] || echo "   Re-run with --with-deps to install them."
        return 0
    fi

    if [ "$WITH_DEPS" != true ] && ask "Install them now?" y; then
        install_dependencies
        [ ${#MISSING_PACMAN[@]} -eq 0 ] && [ ${#MISSING_AUR[@]} -eq 0 ] && return 0
        missing_banner
    fi

    if ! ask "Continue the install without them?" n; then
        printf "\n\033[1;31m󰅙 Install stopped. Nothing was copied.\033[0m\n"
        exit 1
    fi
}

# run_or_warn RETRY CMD...: runs CMD, its output shown as usual. If it fails,
# says so with its last error line and files RETRY for the final report,
# instead of letting the step look like it worked.
run_or_warn() {
    local retry="$1" err
    shift
    # fd 3 is this script's stdout, opened outside the capture: the command's
    # output goes there as usual, only its stderr lands in $err.
    { err="$( { "$@" 2>&1 1>&3 3>&-; } )"; } 3>&1 && return 0
    err="$(tail -n 1 <<<"${err:-exited with an error}")"
    printf "\033[1;33m󰀦 %s failed: %s\033[0m\n" "${1##*/}" "$err"
    FAILED_STEPS+=("$retry|$err")
    return 1
}

missing_banner() {
    printf "\n\033[1;41;97m  󰀦 MISSING PACKAGES  \033[0m\n\n"
    [ ${#MISSING_PACMAN[@]} -gt 0 ] &&
        printf "   \033[1;31mrepos:\033[0m %s\n" "${MISSING_PACMAN[*]}"
    [ ${#MISSING_AUR[@]} -gt 0 ] &&
        printf "   \033[1;31mAUR:\033[0m   %s\n" "${MISSING_AUR[*]}"
    echo
}

# ask QUESTION DEFAULT(y|n). Without a terminal to answer from there is nobody
# to confirm, so it answers no: better stop than install a half working setup.
ask() {
    local reply hint="[y/N]"
    [ "$2" = y ] && hint="[Y/n]"
    [ -t 0 ] || return 1
    read -r -p "   $1 $hint " reply
    reply="${reply:-$2}"
    [[ "$reply" =~ ^[YySs] ]]
}

install_dependencies() {
    local helper

    if [ ${#MISSING_PACMAN[@]} -gt 0 ]; then
        echo "󰑓 sudo pacman -S --needed ${MISSING_PACMAN[*]}"
        sudo pacman -S --needed "${MISSING_PACMAN[@]}" || true
        mapfile -t MISSING_PACMAN < <(pacman -T "${PACMAN_PKGS[@]}")
    fi

    [ ${#MISSING_AUR[@]} -gt 0 ] || return 0

    if ! helper="$(aur_helper)"; then
        echo "󰀦 No AUR helper found (yay or paru); install those by hand."
        return 0
    fi

    echo "󰑓 $helper -S --needed ${MISSING_AUR[*]}"
    "$helper" -S --needed "${MISSING_AUR[@]}" || true
    mapfile -t MISSING_AUR < <(pacman -T "${AUR_PKGS[@]}")
}

# ── Submodules ───────────────────────────

# A clone without --recursive leaves modules/* empty. That is quiet damage: the
# runcat font never installs, and the symlinks for
# claude-usage.sh / sinkswitch / trackpad-battery are skipped without a word.
# So check them out here instead of warning and carrying on regardless.
missing_submodules() {
    local path
    # Read .gitmodules directly: detection must work even without git, so that
    # the summary can still tell you what is missing.
    while IFS= read -r path; do
        # .git is the checkout marker; the folder itself exists either way.
        [ -e "$REPO_PATH/$path/.git" ] || printf '%s\n' "$path"
    done < <(awk -F= '/^[[:space:]]*path[[:space:]]*=/ {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2
    }' "$REPO_PATH/.gitmodules")
}

check_submodules() {
    progress "SUBMODULES"

    if [ ! -f "$REPO_PATH/.gitmodules" ]; then
        echo "󰄬 No submodules declared."
        return 0
    fi

    mapfile -t MISSING_SUBMODULES < <(missing_submodules)
    if [ ${#MISSING_SUBMODULES[@]} -eq 0 ]; then
        echo "󰄬 All submodules checked out."
        return 0
    fi

    echo "󰑓 Fetching ${MISSING_SUBMODULES[*]}"
    git -C "$REPO_PATH" submodule update --init --recursive || true

    mapfile -t MISSING_SUBMODULES < <(missing_submodules)
    if [ ${#MISSING_SUBMODULES[@]} -eq 0 ]; then
        echo "󰄬 Submodules checked out."
    else
        echo "󰀦 Could not fetch: ${MISSING_SUBMODULES[*]}"
    fi
}

# ── Plugins ──────────────────────────────

# Prints "enabled", "disabled", or nothing when hyprpm does not know the plugin.
plugin_state() {
    hyprpm list 2>/dev/null | awk -v name="$1" '
        /Plugin/ && $NF == name { found = 1; next }
        found && /enabled:/     { print ($0 ~ /true/) ? "enabled" : "disabled"; exit }
    '
}

# Sorts every plugin into enabled / disabled / missing, printing as it goes.
read_plugin_states() {
    local name
    MISSING_PLUGINS=()
    DISABLED_PLUGINS=()

    for name in "${PLUGIN_NAMES[@]}"; do
        case "$(plugin_state "$name")" in
            enabled)  echo "󰄬 $name" ;;
            disabled) echo "󰀦 $name is installed but disabled"
                      DISABLED_PLUGINS+=("$name") ;;
            *)        echo "󰀦 $name is not installed"
                      MISSING_PLUGINS+=("$name") ;;
        esac
    done
}

# hyprpm compiles every plugin against the running Hyprland, which is slow and
# can fail, so the default is to report and let you decide.
check_plugins() {
    progress "PLUGINS"

    if ! command -v hyprpm >/dev/null 2>&1 || ! hyprctl version >/dev/null 2>&1; then
        echo "󰀦 hyprpm missing or Hyprland not running, skipping the plugin check."
        return 0
    fi

    read_plugin_states
    [ $(( ${#MISSING_PLUGINS[@]} + ${#DISABLED_PLUGINS[@]} )) -gt 0 ] || return 0

    if [ "$WITH_PLUGINS" != true ]; then
        echo "   Re-run with --with-plugins to install them; listed again at the end."
        return 0
    fi

    install_plugins
}

install_plugins() {
    local name
    echo "󰑓 Installing plugins with hyprpm; this compiles them and takes a while."
    hyprpm update || true

    for name in "${MISSING_PLUGINS[@]}"; do
        hyprpm add "${PLUGIN_REPOS[$name]}" || true
    done
    for name in "${MISSING_PLUGINS[@]}" "${DISABLED_PLUGINS[@]}"; do
        hyprpm enable "$name" || true
    done

    # Re-read the real state instead of assuming the commands worked.
    read_plugin_states
}

set_permissions() {
    progress "PERMISSIONS"
    echo "󰒓 Setting execute permissions on scripts..."
    # lib/ too: Waybar and the keybindings run those directly.
    find "$REPO_PATH/bin" "$REPO_PATH/lib" -type f ! -path '*/__pycache__/*' -exec chmod +x {} \;
    # Lockscreen helpers ship inside dotconfig, not bin, because only
    # hyprlock-flow.sh is meant to be invoked directly.
    find "$REPO_PATH/dotconfig/hypr/hyprlock" -type f -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true

    local link target
    while IFS= read -r -d '' link; do
        target="$(readlink -f "$link" 2>/dev/null || true)"
        if [ -n "$target" ] && [ -f "$target" ]; then
            chmod +x "$target"
        fi
    done < <(find "$REPO_PATH/bin" "$REPO_PATH/lib" -maxdepth 1 -type l -print0)
}

copy_configs() {
    progress "CONFIG FILES"
    echo "󰆐 Copying configuration files..."

    # The repo ships starting copies of files that are generated on your
    # machine afterwards: the wallust palette and the monitor layout and
    # Waybar bars (the theme and monitors steps write their own). Those are
    # never written over, not even for a moment: Hyprland reloads on every
    # config change, and a moment with the repo's generic monitors_active.lua
    # switched every screen to it and back. A fresh machine still gets them.
    local generated=(
        hypr/colors.lua rofi/hyprflow/colors.rasi wlogout/colors.css cava/themes/wallust
        hypr/monitors_active.lua waybar/config
    )

    local excludes=() path
    for path in "${generated[@]}"; do excludes+=(--exclude="./$path"); done
    # tar, not cp: it can leave paths out. Dotfiles included.
    tar -C "$REPO_PATH/dotconfig" "${excludes[@]}" -cf - . | tar -C "$CONFIG_DEST" -xf -

    for path in "${generated[@]}"; do
        [ -e "$CONFIG_DEST/$path" ] || [ ! -e "$REPO_PATH/dotconfig/$path" ] && continue
        mkdir -p "$CONFIG_DEST/$(dirname "$path")"
        cp -f "$REPO_PATH/dotconfig/$path" "$CONFIG_DEST/$path"
    done

    # qt5ct/qt6ct want the stylesheet as an absolute path; the repo says ~.
    local qt
    for qt in qt5ct qt6ct; do
        [ -f "$CONFIG_DEST/$qt/$qt.conf" ] &&
            sed -i "s|^stylesheets=~/|stylesheets=$HOME/|" "$CONFIG_DEST/$qt/$qt.conf"
    done
}

setup_runcat() {
    progress "RUNCAT"
    # The runners are fonts (cat, chicken) shipped by the runcat-text
    # submodule, along with its config.json.
    local font_dir="$HOME/.local/share/fonts" font
    if [ ! -d "$REPO_PATH/modules/runcat-text" ]; then
        printf "\033[1;33m%s runcat-text submodule missing, skipping the runner fonts.\033[0m\n" "󰀦"
        return 0
    fi

    echo "󰛖 Installing the runner fonts..."
    mkdir -p "$font_dir"
    for font in "$REPO_PATH/modules/runcat-text"/*.ttf; do
        cp -f "$font" "$font_dir/"
    done
    fc-cache -f "$font_dir"
}

create_symlinks() {
    progress "BINARIES"
    echo "󰌹 Creating symbolic links for binaries..."
    local broken=()
    # bin/ holds the commands you run, so it goes on PATH. lib/ holds what only
    # Waybar, the keybindings or other scripts call; it is linked off PATH and
    # the configs call it by its full path.
    link_dir "$REPO_PATH/bin" "$BIN_FILES_PATH"
    link_dir "$REPO_PATH/lib" "$LIB_FILES_PATH"

    # Scripts that moved or went away leave dangling links behind. Remove
    # those, and only those that point into this repo.
    local link
    for link in "$BIN_FILES_PATH"/* "$LIB_FILES_PATH"/*; do
        [ -L "$link" ] && [ ! -e "$link" ] || continue
        [[ "$(readlink "$link")" == "$REPO_PATH"/* ]] && rm -f "$link"
    done

    if [ ${#broken[@]} -gt 0 ]; then
        printf "\033[1;33m%s Skipped, submodule missing: %s\033[0m\n" "󰀦" "${broken[*]}"
    fi
}

# link_dir SRC DEST: links every entry of SRC into DEST. Uses the caller's
# `broken` array for links whose submodule is not checked out.
link_dir() {
    local file
    mkdir -p "$2"
    for file in "$1"/*; do
        case "$(basename "$file")" in __pycache__) continue ;; esac
        # Directories too, linked whole, should a script ever need one.
        if [ -f "$file" ] || [ -d "$file" ]; then
            ln -sfn "$file" "$2/$(basename "$file")"
        elif [ -L "$file" ]; then
            # -f follows the link, so a dangling one lands here: its submodule
            # is not checked out. Say so instead of skipping in silence.
            broken+=("$(basename "$file")")
        fi
    done
}

apply_theme() {
    progress "THEME"
    echo "󰏘 Setting up colors..."
    # --no-restart: we bounce Waybar once at the end, not once per step.
    run_or_warn "wallust-theme-manager.sh --restore-default" \
        "$REPO_PATH/bin/wallust-theme-manager.sh" --restore-default --notify --no-restart

    # Fallback for a wallust that failed: the repo's copies fill in only what
    # it did not write, so they never replace a fresh palette.
    mkdir -p "$HOME/.cache/wallust/colors"
    cp -n "$REPO_PATH/dotconfig/wallust/colors"/* "$HOME/.cache/wallust/colors/" 2>/dev/null || true

    # Dark GTK apps: GTK 4 and libadwaita read color-scheme, GTK 3 the theme.
    # Qt (qt6ct/qt5ct) and pinentry come in with the config step.
    if command -v gsettings >/dev/null 2>&1; then
        echo "󰔎 Dark mode for GTK apps..."
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' 2>/dev/null || true
    fi
}

setup_lockscreen() {
    progress "LOCKSCREEN"

    # Seed the default avatar before geometry.sh runs, since that would
    # otherwise draw the Arch glyph fallback. Only when nothing is there:
    # an existing avatar is the user's own and is never replaced.
    local avatar="$CONFIG_DEST/hypr/avatar.png"
    if [ ! -f "$avatar" ] && [ -f "$REPO_PATH/assets/avatar.png" ]; then
        echo "󰭄 Installing default avatar..."
        mkdir -p "$CONFIG_DEST/hypr"
        cp "$REPO_PATH/assets/avatar.png" "$avatar"
    fi

    echo "󰌾 Generating hyprlock geometry and backdrop..."
    # hyprlock.conf sources hyprlock-geometry.conf and hyprlock-extras.conf,
    # both generated, so a clean install would start with them missing. Runs
    # after apply_theme because the avatar picks up the palette colour, and
    # calls the installed copy so the paths it writes match runtime.
    run_or_warn "~/.config/hypr/hyprlock/geometry.sh" "$CONFIG_DEST/hypr/hyprlock/geometry.sh"
}

setup_monitors() {
    progress "MONITORS"
    # The wizard asks questions, so it needs a terminal. Piped or unattended,
    # fall back to the saved profile instead of hanging on a prompt.
    if [ -t 0 ]; then
        echo "󰍹 Configuring monitors..."
        "$REPO_PATH/bin/monitors.sh" setup || "$REPO_PATH/bin/monitors.sh" apply || true
    else
        echo "󰍹 Applying monitor layout (saved profile / default)..."
        run_or_warn "monitors.sh apply" "$REPO_PATH/bin/monitors.sh" apply
    fi
}

reload_hyprland() {
    progress "RELOAD"
    if command -v hyprpm >/dev/null 2>&1; then
        echo "󰑓 Reloading Hyprpm..."
        run_or_warn "hyprpm reload" hyprpm reload
    fi

    echo "󰑓 Reloading Hyprland..."
    run_or_warn "hyprctl reload" hyprctl reload
}

setup_zsh() {
    progress "ZSH"
    local src="$REPO_PATH/dotconfig/zsh/.zshrc"
    local dest="$HOME/.zshrc"
    local reply zsh_path

    # This one touches your shell, not just ~/.config, so it always asks.
    if [ -f "$dest" ]; then
        read -r -p "  ~/.zshrc already exists. Overwrite? [y/N] " reply
        if [[ ! "$reply" =~ ^[Yy]$ ]]; then
            echo "  Skipped."
            return 0
        fi
        cp "$dest" "$dest.bak"
        echo "  Backup saved to ~/.zshrc.bak"
    fi

    cp "$src" "$dest"
    echo "󰄬 ~/.zshrc installed."

    zsh_path="$(command -v zsh)" || return 0
    if [ "$SHELL" != "$zsh_path" ]; then
        read -r -p "  Set zsh as your default shell? [y/N] " reply
        [[ "$reply" =~ ^[Yy]$ ]] && chsh -s "$zsh_path"
    fi
}

restart_waybar() {
    "$REPO_PATH/lib/waybar-restart.sh"
}

# ─────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────

if [ "$FULL_RUN" = true ]; then
    echo "󰣇 Installing HyprFlow-Arch..."
else
    echo "󰣇 HyprFlow-Arch: ${!RUN[*]}"
fi
mkdir -p "$BIN_FILES_PATH" "$CONFIG_DEST" "$HOME/Pictures/Screenshots"

if want check; then
    check_dependencies
    check_submodules
    check_plugins
fi

if want config; then
    set_permissions
    copy_configs
    setup_runcat
    create_symlinks
fi

want theme      && apply_theme
want lockscreen && setup_lockscreen

# Anything that rewrote files under ~/.config needs the compositor to re-read them.
if want config || want theme || want lockscreen; then
    reload_hyprland
fi

want monitors && setup_monitors
want zsh      && setup_zsh

# monitors.sh restarts Waybar itself after regenerating the bars, so only do it
# here when that step did not run. A config sync regenerates the bars first:
# the Waybar config is built from bars.json, which the copy just updated.
if ! want monitors && { want config || want theme; }; then
    want config && run_or_warn "monitors.sh apply" "$REPO_PATH/bin/monitors.sh" apply
    restart_waybar
fi

final_report() {
    local pending name
    pending=$(( ${#MISSING_PACMAN[@]} + ${#MISSING_AUR[@]} + ${#MISSING_SUBMODULES[@]} +
                ${#MISSING_PLUGINS[@]} + ${#DISABLED_PLUGINS[@]} + ${#FAILED_STEPS[@]} ))

    if [ "$pending" -eq 0 ]; then
        if [ "$FULL_RUN" = true ]; then
            printf "\n\033[1;32m󰄬 Installation complete!\033[0m\n"
        else
            printf "\n\033[1;32m󰄬 Done.\033[0m\n"
        fi
        return 0
    fi

    printf "\n\033[1;33m󰀦 Installation finished, with things left to do:\033[0m\n\n"

    [ ${#MISSING_PACMAN[@]} -gt 0 ] &&
        printf "   sudo pacman -S --needed %s\n" "${MISSING_PACMAN[*]}"
    [ ${#MISSING_AUR[@]} -gt 0 ] &&
        printf "   yay -S --needed %s\n" "${MISSING_AUR[*]}"
    [ ${#MISSING_SUBMODULES[@]} -gt 0 ] &&
        printf "   git submodule update --init --recursive   (%s)\n" "${MISSING_SUBMODULES[*]}"

    for name in "${MISSING_PLUGINS[@]}"; do
        printf "   hyprpm add %s && hyprpm enable %s\n" "${PLUGIN_REPOS[$name]}" "$name"
    done
    for name in "${DISABLED_PLUGINS[@]}"; do
        printf "   hyprpm enable %s\n" "$name"
    done

    local failed
    for failed in "${FAILED_STEPS[@]}"; do
        printf "   %-44s (failed: %s)\n" "${failed%%|*}" "${failed#*|}"
    done

    printf "\n   Or re-run: bash install.sh --with-deps --with-plugins\n"
}
final_report
