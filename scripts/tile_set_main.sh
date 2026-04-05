#!/usr/bin/env bash
set -euo pipefail

# tile_set_main.sh — Identify which window is your main character
#
# Lists all EQ windows with their index numbers. You visually check
# which window has your main character, then tell us the index.
# The mapping is saved so future `make tile` gets it right.
#
# Usage: bash scripts/tile_set_main.sh [INDEX]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config_reader.sh
source "${SCRIPT_DIR}/config_reader.sh"

PREFIX="${NN_PREFIX}"
HELPER="${SCRIPT_DIR}/../helpers/wine_helper.exe"

if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    cat <<EOF
Usage: $(basename "$0") [INDEX]

Identify which EQ window is your main character.

Without INDEX: lists windows and asks you to pick.
With INDEX:    saves window INDEX as the main character.

The mapping is saved to ~/.local/share/norrath-native/hwnd-character-map
and used by make tile / make fix for future tiling.
EOF
    exit 0
fi

if [[ ! -f "${HELPER}" ]]; then
    nn_log "ERROR: helpers/wine_helper.exe not found. Run: make build"
    exit 1
fi

# Get current windows
nn_log "Current EQ windows:"
nn_log ""

local_count=0
declare -a local_hwnds=()
while IFS='|' read -r idx hwnd pos size _pid; do
    nn_log "  [${idx}] HWND ${hwnd} at ${pos} size ${size}"
    local_hwnds+=("${hwnd}")
    local_count=$((local_count + 1))

    # Briefly flash each window so user can see which is which
    WINEPREFIX="${PREFIX}" DISPLAY=:0 wine "${HELPER}" focus-hwnd "0x${hwnd}" 2>/dev/null
    sleep 0.5
done < <(WINEPREFIX="${PREFIX}" DISPLAY=:0 wine "${HELPER}" find 2>/dev/null)

if [[ "${local_count}" -eq 0 ]]; then
    nn_log "No EQ windows found."
    exit 1
fi

nn_log ""

# Get user's choice
main_idx="${1:-}"
if [[ -z "${main_idx}" ]]; then
    printf 'Which window number is %s? [0-%d]: ' "${NN_MAIN_CHARACTER:-your main}" "$((local_count - 1))"
    read -r main_idx
fi

if [[ ! "${main_idx}" =~ ^[0-9]+$ ]] || [[ "${main_idx}" -ge "${local_count}" ]]; then
    nn_log "ERROR: Invalid index. Must be 0-$((local_count - 1))"
    exit 1
fi

# Save mapping
state_dir="${HOME}/.local/share/norrath-native"
mkdir -p "${state_dir}"
hwnd_map="${state_dir}/hwnd-character-map"

# Clear old mapping and save new one
> "${hwnd_map}"
main_hwnd="${local_hwnds[${main_idx}]}"
echo "${main_hwnd}=${NN_MAIN_CHARACTER:-main}" >> "${hwnd_map}"

nn_log "Saved: window ${main_idx} (HWND ${main_hwnd}) = ${NN_MAIN_CHARACTER:-main}"
nn_log ""
nn_log "Now run 'make fix' to re-tile with the correct main window."
