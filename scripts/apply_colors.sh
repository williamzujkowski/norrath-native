#!/usr/bin/env bash
# shellcheck disable=SC2034  # Variables used via nameref
set -euo pipefail

# apply_colors.sh — Apply optimized chat color scheme for raid readability
#
# Designed for EverQuest raiding on Linux. Color philosophy:
#   Communication: each channel is instantly distinguishable
#   Your combat:   warm tones (yellow/gold)
#   Your healing:  cool tones (mint/blue)
#   Incoming:      alert colors (red/salmon)
#   Others:        dimmed gray-blue (reduces raid spam)
#   Alerts:        high-contrast red (death, low HP)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config_reader.sh
source "${SCRIPT_DIR}/config_reader.sh"

DRY_RUN=0
PREFIX="${NN_PREFIX}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Apply an optimized chat color scheme to eqclient.ini.

The scheme is designed for raid readability:
  - Tells: bright pink (unmissable)
  - Guild: bright green
  - Group: soft blue
  - Raid:  orange
  - Your damage: warm yellow/gold
  - Your healing: cool mint/blue
  - Others' combat: dimmed gray (reduces spam)
  - Death/Low HP: bright red alert

Options:
  --prefix PATH   Override WINEPREFIX
  --dry-run       Preview changes without writing
  -h, --help      Show this help
EOF
    exit 0
}

# Color application delegated to TypeScript (src/config-injector.ts).
# cli_cmd colors:apply writes directly to the INI file.
apply_colors() {
    local ini_file="$1"
    local result
    result="$(cli_cmd colors:apply "${ini_file}" 2>/dev/null)"
    local changed
    changed="$(echo "${result}" | grep -oP '"changed": \K\d+' || echo '0')"
    printf '%d' "${changed}"
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --prefix)
                if [[ $# -lt 2 ]]; then nn_log "ERROR: --prefix requires a value"; exit 1; fi
                PREFIX="$2"; shift 2 ;;
            --dry-run) DRY_RUN=1; shift ;;
            -h|--help) usage ;;
            *) nn_log "ERROR: Unknown option: $1"; exit 1 ;;
        esac
    done

    local ini_file="${PREFIX}/drive_c/EverQuest/eqclient.ini"

    if [[ ! -f "${ini_file}" ]]; then
        nn_log "ERROR: eqclient.ini not found at ${ini_file}"
        nn_log "Run 'make deploy' first."
        exit 1
    fi

    if [[ "${DRY_RUN}" -eq 1 ]]; then
        nn_log "Preview: optimized color scheme for ${ini_file}"
        nn_log ""
        nn_log "Key changes:"
        nn_log "  Tell:     white → bright pink (#ff80ff)"
        nn_log "  Guild:    red → bright green (#00e600)"
        nn_log "  Group:    blue → soft blue (#82b4ff)"
        nn_log "  Raid:     white → orange (#ffa500)"
        nn_log "  Shout:    dark green → salmon (#ff6464)"
        nn_log "  Others:   bright → dimmed gray (#6e8296)"
        nn_log "  Healing:  mixed → mint/blue family"
        nn_log "  Low HP:   dark red → BRIGHT RED (#ff0000)"
        nn_log ""
        local count
        count="$(apply_colors "${ini_file}")"
        nn_log "Would change ${count} color values."
    else
        nn_log "Applying optimized color scheme to ${ini_file}..."
        local count
        count="$(apply_colors "${ini_file}")"
        nn_log "Updated ${count} color values."
        nn_log "Reload UI in-game with /loadskin to see changes."
    fi
}

main "$@"
