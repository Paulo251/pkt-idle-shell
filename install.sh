#!/usr/bin/env bash
#
# install.sh -- installs pkt-idle-shell on an Arch-based system.
#
# Safe to run more than once. Whatever would be replaced goes to a dated backup
# first, and the game save (~/.config/poke-equipo) is never touched.
set -Eeuo pipefail

REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
SRC="$REPO/home"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/pkt-idle-shell"
BACKUP="$STATE/backups/$(date +%Y%m%d-%H%M%S)"

DRY_RUN=0
PACKAGES=1
DATA=1
SERVICES=1
LANG_CHOICE=""

usage() {
    cat <<'EOF'
Usage: ./install.sh [options]

  --dry-run       show what would be done and change nothing
  --no-packages   do not install pacman or AUR packages
  --no-data       do not download Pokémon data and sprites
  --no-services   do not enable or restart user services
  --lang CODE     interface language: pt, en, es or it
  -h, --help      show this help
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)     DRY_RUN=1 ;;
        --no-packages) PACKAGES=0 ;;
        --no-data)     DATA=0 ;;
        --no-services) SERVICES=0 ;;
        --lang)
            LANG_CHOICE="${2:-}"
            case "$LANG_CHOICE" in
                pt|en|es|it) shift ;;
                *) echo "error: --lang must be pt, en, es or it" >&2; exit 2 ;;
            esac
            ;;
        -h|--help)     usage; exit 0 ;;
        *)             echo "error: unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

step() { printf '\n\033[1;36m==>\033[0m %s\n' "$1"; }
info() { printf '    %s\n' "$1"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$1" >&2; }

run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '    [dry-run] %s\n' "$*"
    else
        "$@"
    fi
}

read_list() { grep -Ev '^[[:space:]]*(#|$)' "$1"; }

check_system() {
    step "Checking the system"
    if [ "$(id -u)" -eq 0 ]; then
        echo "error: run this as your normal user, not as root" >&2
        exit 1
    fi
    if [ ! -d "$SRC" ]; then
        echo "error: $SRC not found; run this from a full clone" >&2
        exit 1
    fi
    if [ "$PACKAGES" -eq 1 ] && ! command -v pacman >/dev/null 2>&1; then
        echo "error: pacman not found. On other systems use --no-packages and install the" >&2
        echo "       dependencies listed in packages/ yourself." >&2
        exit 1
    fi
    info "repository: $REPO"
}

install_packages() {
    [ "$PACKAGES" -eq 1 ] || return 0
    step "Installing packages"
    local missing=() aur_missing=() pkg helper=""
    while IFS= read -r pkg; do
        pacman -Q "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
    done < <(read_list "$REPO/packages/pacman.txt")
    while IFS= read -r pkg; do
        pacman -Q "$pkg" >/dev/null 2>&1 || aur_missing+=("$pkg")
    done < <(read_list "$REPO/packages/aur.txt")

    if [ "${#missing[@]}" -gt 0 ]; then
        run sudo pacman -S --needed "${missing[@]}"
    else
        info "official packages already installed"
    fi

    if [ "${#aur_missing[@]}" -eq 0 ]; then
        info "AUR packages already installed"
        return 0
    fi
    command -v paru >/dev/null 2>&1 && helper=paru
    [ -z "$helper" ] && command -v yay >/dev/null 2>&1 && helper=yay
    if [ -n "$helper" ]; then
        run "$helper" -S --needed "${aur_missing[@]}"
    else
        warn "no AUR helper found (paru or yay). Install these yourself: ${aur_missing[*]}"
    fi
}

link_path() {
    local rel="$1" source="$SRC/$1" target="$HOME/$1"
    if [ -L "$target" ] && [ "$(readlink -f "$target")" = "$(readlink -f "$source")" ]; then
        return 0
    fi
    if [ -e "$target" ] || [ -L "$target" ]; then
        run mkdir -p "$(dirname "$BACKUP/$rel")"
        run mv "$target" "$BACKUP/$rel"
        info "backed up ~/$rel"
    fi
    run mkdir -p "$(dirname "$target")"
    run ln -s "$source" "$target"
    info "linked ~/$rel"
}

link_files() {
    step "Linking the desktop into your home"
    local path
    link_path ".config/quickshell"
    link_path ".config/hypr"
    link_path ".local/lib/pokeidle"
    for path in "$SRC"/.config/systemd/user/* "$SRC"/.local/bin/*; do
        link_path "${path#"$SRC"/}"
    done
    if [ -d "$BACKUP" ]; then
        info "previous files are in $BACKUP"
    fi
}

generate_monitors() {
    local file="$SRC/.config/hypr/config/monitors.lua"
    [ -e "$file" ] && return 0
    step "Generating the monitor configuration"
    local name="" mode="preferred" scale="1"
    if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 \
        && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        name="$(hyprctl monitors -j 2>/dev/null | jq -r '.[0].name // empty')"
        if [ -n "$name" ]; then
            mode="$(hyprctl monitors -j | jq -r '.[0] | "\(.width)x\(.height)@\(.refreshRate | round)"')"
            scale="$(hyprctl monitors -j | jq -r '.[0].scale')"
        fi
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
        info "[dry-run] would write monitors.lua (${name:-any monitor}, $mode)"
        return 0
    fi
    cat >"$file" <<EOF
-- Generated by install.sh for this machine (not tracked by git).
MONITOR1 = "$name"

hl.monitor({
    output   = MONITOR1,
    mode     = "$mode",
    position = "0x0",
    scale    = "$scale",
})
EOF
    info "monitor: ${name:-any}, $mode"
}

set_language() {
    local file="$HOME/.config/quickshell-rice.json" lang="$LANG_CHOICE"
    [ -z "$lang" ] && [ -e "$file" ] && return 0
    if [ -z "$lang" ]; then
        case "${LANG:-en}" in
            pt*) lang=pt ;;
            es*) lang=es ;;
            it*) lang=it ;;
            *)   lang=en ;;
        esac
    fi
    step "Setting the interface language: $lang"
    [ "$DRY_RUN" -eq 1 ] && { info "[dry-run] would set language to $lang"; return 0; }
    mkdir -p "$(dirname "$file")"
    python3 - "$file" "$lang" <<'PY'
import json
import sys
from pathlib import Path

path, lang = Path(sys.argv[1]), sys.argv[2]
data = json.loads(path.read_text()) if path.exists() else {}
data["language"] = lang
path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
PY
}

prepare_wallpaper() {
    step "Preparing the wallpaper and palette"
    local dir="$HOME/Pictures/wallpapers" image
    image="$(find "$dir" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) \
        2>/dev/null | sort | head -n 1 || true)"
    if [ -z "$image" ]; then
        image="$dir/pkt-idle-default.png"
        run mkdir -p "$dir"
        if command -v magick >/dev/null 2>&1; then
            run magick -size 1920x1080 gradient:'#222a38-#151a24' "$image"
        else
            warn "ImageMagick not found; add an image to $dir"
            return 0
        fi
    fi
    if [ ! -e "$HOME/.cache/wal/colors.json" ] && command -v wal >/dev/null 2>&1; then
        run wal -i "$image" -n -q -s -t
    fi
    info "wallpaper: $image"
}

download_data() {
    [ "$DATA" -eq 1 ] || return 0
    step "Downloading Pokémon data"
    if [ "$DRY_RUN" -eq 1 ]; then
        info "[dry-run] would download data from PokeAPI"
        return 0
    fi
    local bin="$HOME/.local/bin" tool log="$STATE/data-download.log"
    mkdir -p "$STATE"
    for tool in poke-types poke-evolutions poke-names; do
        info "$tool"
        "$bin/$tool" -q >/dev/null 2>&1 || "$bin/$tool" >/dev/null 2>&1 \
            || warn "$tool failed; run it again when you are online"
    done
    info "sprites and game data continue in the background (log: $log)"
    nohup setsid bash -c '
        bin="$HOME/.local/bin"; lib="$HOME/.local/lib/pokeidle"
        "$bin/poke-sprites"; "$bin/poke-dex" --todo; "$bin/poke-api" itens
        python3 "$lib/prefetch_ligas.py"; python3 "$lib/prefetch_modos.py"; "$bin/poke-theme" index
    ' >"$log" 2>&1 &
}

enable_services() {
    [ "$SERVICES" -eq 1 ] || return 0
    step "Enabling user services"
    command -v systemctl >/dev/null 2>&1 || { warn "systemctl not found"; return 0; }
    run systemctl --user daemon-reload || warn "could not reload the user services"
    local unit
    for unit in quickshell.service poke-mood.service hypridle.service wl_shimeji.socket; do
        run systemctl --user enable "$unit" >/dev/null 2>&1 || warn "could not enable $unit"
    done
    if [ -n "${WAYLAND_DISPLAY:-}" ]; then
        # Delayed, so restarting the shell cannot end a terminal that it launched.
        run systemd-run --user --quiet --on-active=2 systemctl --user restart quickshell.service \
            || warn "could not restart Quickshell"
    fi
}

finish() {
    step "Done"
    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) warn "add ~/.local/bin to your PATH" ;;
    esac
    info "Start a Hyprland session, then press SUPER+I to open PokéIdle."
}

check_system
install_packages
link_files
generate_monitors
set_language
prepare_wallpaper
download_data
enable_services
finish
