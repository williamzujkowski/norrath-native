#!/usr/bin/env bash
set -euo pipefail

# install_shortcuts.sh — Create desktop shortcuts and taskbar pins
#
# Creates .desktop entries for EverQuest and EQLogParser with proper
# icons, and pins them to the GNOME taskbar (favorites).
#
# Called automatically by deploy and parser install scripts.
# Safe to run multiple times (idempotent).
#
# Usage: bash scripts/install_shortcuts.sh [--parser-only]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config_reader.sh
source "${SCRIPT_DIR}/config_reader.sh"

PREFIX="${NN_PREFIX}"
PARSER_ONLY=0
APPS_DIR="${HOME}/.local/share/applications"
ICONS_DIR="${HOME}/.local/share/icons/norrath-native"

if [[ "${1:-}" == "--parser-only" ]]; then
    PARSER_ONLY=1
fi

if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    cat <<EOF
Usage: $(basename "$0") [--parser-only]

Create desktop shortcuts with proper icons for EQ and EQLogParser.

Options:
  --parser-only   Only create/update EQLogParser shortcut
  -h, --help      Show this help
EOF
    exit 0
fi

mkdir -p "${APPS_DIR}" "${ICONS_DIR}"

# ─── Icon Extraction ──────────────────────────────────────────────────────────

install_eq_icon() {
    local ico_src="${PREFIX}/drive_c/EverQuest/Everquest.ico"
    local icon_dest="${ICONS_DIR}/everquest.png"

    if [[ -f "${icon_dest}" ]]; then
        return 0
    fi

    if [[ -f "${ico_src}" ]]; then
        # Convert .ico to .png via ImageMagick (pick largest layer)
        if command -v convert &>/dev/null; then
            convert "${ico_src}[0]" -resize 128x128 "${icon_dest}" 2>/dev/null && return 0
        fi
        # Fallback: copy the .ico directly (GNOME can display it)
        cp "${ico_src}" "${ICONS_DIR}/everquest.ico" 2>/dev/null
        icon_dest="${ICONS_DIR}/everquest.ico"
    fi
}

install_parser_icon() {
    local icon_dest="${ICONS_DIR}/eqlogparser.png"

    if [[ -f "${icon_dest}" ]]; then
        return 0
    fi

    # Try to extract icon from the .exe via icoutils
    local exe="${PREFIX}/drive_c/Program Files/EQLogParser/EQLogParser.exe"
    if [[ -f "${exe}" ]] && command -v wrestool &>/dev/null && command -v icotool &>/dev/null; then
        local tmp_ico
        tmp_ico="$(mktemp --suffix=.ico)"
        wrestool -x -t 14 "${exe}" > "${tmp_ico}" 2>/dev/null || true
        if [[ -s "${tmp_ico}" ]]; then
            icotool -x -o "${icon_dest}" "${tmp_ico}" 2>/dev/null || true
        fi
        rm -f "${tmp_ico}"
    fi

    # If no icon extracted, use a generic game icon
    if [[ ! -f "${icon_dest}" ]]; then
        # Use the EQ icon as fallback, or wine icon
        if [[ -f "${ICONS_DIR}/everquest.png" ]]; then
            cp "${ICONS_DIR}/everquest.png" "${icon_dest}"
        fi
    fi
}

# ─── Desktop Entries ──────────────────────────────────────────────────────────

create_eq_shortcut() {
    local desktop_file="${APPS_DIR}/everquest.desktop"

    install_eq_icon

    local icon_path="${ICONS_DIR}/everquest.png"
    if [[ ! -f "${icon_path}" ]]; then
        icon_path="${ICONS_DIR}/everquest.ico"
    fi
    if [[ ! -f "${icon_path}" ]]; then
        icon_path="wine"
    fi

    cat > "${desktop_file}" << EOF
[Desktop Entry]
Name=EverQuest
Comment=Launch EverQuest via Wine (norrath-native)
Exec=env WINEPREFIX=${PREFIX} wine ${PREFIX}/drive_c/EverQuest/LaunchPad.exe --disable-gpu
Type=Application
Categories=Game;
Icon=${icon_path}
StartupWMClass=launchpad.exe
EOF

    nn_log "Created EverQuest shortcut: ${desktop_file}"
}

create_parser_shortcut() {
    local desktop_file="${APPS_DIR}/eqlogparser.desktop"
    local exe="${PREFIX}/drive_c/Program Files/EQLogParser/EQLogParser.exe"

    if [[ ! -f "${exe}" ]]; then
        return 0
    fi

    install_parser_icon

    local icon_path="${ICONS_DIR}/eqlogparser.png"
    if [[ ! -f "${icon_path}" ]]; then
        icon_path="wine"
    fi

    cat > "${desktop_file}" << EOF
[Desktop Entry]
Name=EQLogParser
Comment=EverQuest DPS meter and trigger system
Exec=env WINEPREFIX=${PREFIX} MONO_THREADS_SUSPEND=preemptive wine "${exe}"
Type=Application
Categories=Game;Utility;
Icon=${icon_path}
StartupWMClass=eqlogparser.exe
EOF

    nn_log "Created EQLogParser shortcut: ${desktop_file}"
}

# ─── Taskbar Pinning ──────────────────────────────────────────────────────────

pin_to_taskbar() {
    local app_id="$1"

    # Only works on GNOME
    if ! command -v gsettings &>/dev/null; then
        return 0
    fi

    local current
    current="$(gsettings get org.gnome.shell favorite-apps 2>/dev/null || echo '[]')"

    # Check if already pinned
    if echo "${current}" | grep -q "'${app_id}'"; then
        return 0
    fi

    # Add to favorites
    local updated
    updated="$(echo "${current}" | sed "s/]/, '${app_id}']/" | sed "s/\[, /[/")"
    gsettings set org.gnome.shell favorite-apps "${updated}" 2>/dev/null || true
    nn_log "Pinned ${app_id} to taskbar"
}

# ─── Main ─────────────────────────────────────────────────────────────────────

if [[ "${PARSER_ONLY}" -eq 0 ]]; then
    create_eq_shortcut
    pin_to_taskbar "everquest.desktop"
fi

create_parser_shortcut
pin_to_taskbar "eqlogparser.desktop"

nn_log "Desktop shortcuts installed."
