#!/usr/bin/env bash
set -euo pipefail

# resolution_manager.sh — Detect, set, and manage display resolution
#
# Auto-detects primary monitor resolution and configures:
# - Wine virtual desktop to match
# - EQ client VideoMode section
# - Chat window positions scaled for the resolution
#
# Commands:
#   detect    — Show detected monitor resolution
#   apply     — Set Wine + EQ to detected (or specified) resolution
#   resize    — Change resolution and rescale all UI positions

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config_reader.sh
source "${SCRIPT_DIR}/config_reader.sh"

PREFIX="${NN_PREFIX}"
DRY_RUN=0
COMMAND="${1:-help}"

usage() {
    cat <<EOF
Usage: $(basename "$0") <command> [OPTIONS]

Manage display resolution for EverQuest under Wine.

IMPORTANT: EQ only supports 16:9 aspect ratio without distortion.
On ultrawide monitors (21:9), the Wine desktop uses your full screen
for tiling space, but EQ's game rendering is clamped to 16:9 to
prevent floating particle effects and fish-eye distortion.

Commands:
  detect             Show detected monitor and recommended EQ resolution
  apply              Auto-configure (smart: ultrawide-aware)
  apply --resolution WxH   Set a specific EQ resolution

Options:
  --prefix PATH      Override WINEPREFIX
  --dry-run          Preview changes without writing
  -h, --help         Show this help

Examples:
  $(basename "$0") detect
  $(basename "$0") apply
  $(basename "$0") apply --resolution 2560x1440
EOF
    exit 0
}

log() {
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    printf '[%s] %s\n' "${timestamp}" "$*"
}

# Detect primary monitor resolution via xrandr
detect_resolution() {
    local res
    res="$(DISPLAY=:0 xrandr 2>/dev/null | grep " connected primary" | grep -oP '\d+x\d+' | head -1)"

    # Fallback: first connected monitor
    if [[ -z "${res}" ]]; then
        res="$(DISPLAY=:0 xrandr 2>/dev/null | grep " connected" | grep -oP '\d+x\d+' | head -1)"
    fi

    # Final fallback
    if [[ -z "${res}" ]]; then
        res="1920x1080"
    fi

    printf '%s' "${res}"
}

# Clamp resolution to 16:9 aspect ratio (EQ's max supported)
# On ultrawide, this returns the largest 16:9 that fits in the height
# e.g., 3440x1440 → 2560x1440 (game), but Wine desktop stays 3440x1440 (tiling)
clamp_to_16x9() {
    local res="$1"
    local width="${res%%x*}"
    local height="${res##*x}"

    # Check aspect ratio: 16:9 = 1.777...
    local ratio
    ratio="$(echo "${width} ${height}" | awk '{printf "%.2f", $1/$2}')"

    if awk "BEGIN {exit !(${ratio} > 1.78)}" 2>/dev/null; then
        # Wider than 16:9 — clamp width to 16:9 at this height
        local clamped_w=$(( height * 16 / 9 ))
        printf '%dx%d' "${clamped_w}" "${height}"
    else
        # 16:9 or narrower — use as-is
        printf '%s' "${res}"
    fi
}

# Check if a resolution is ultrawide (wider than 16:9)
is_ultrawide() {
    local res="$1"
    local width="${res%%x*}"
    local height="${res##*x}"
    local ratio
    ratio="$(echo "${width} ${height}" | awk '{printf "%.2f", $1/$2}')"
    awk "BEGIN {exit !(${ratio} > 1.78)}" 2>/dev/null
}

# Get current Wine virtual desktop resolution
get_current_resolution() {
    local reg_file="${PREFIX}/user.reg"
    if [[ -f "${reg_file}" ]]; then
        grep '"Default"=' "${reg_file}" 2>/dev/null | grep -oP '\d+x\d+' | head -1
    fi
}

# Set Wine virtual desktop resolution
set_wine_resolution() {
    local res="$1"
    local width="${res%%x*}"
    local height="${res##*x}"

    log "Setting Wine virtual desktop to ${res}..."

    if [[ "${DRY_RUN}" -eq 1 ]]; then
        log "  [DRY-RUN] Would set desktop to ${width}x${height}"
        return 0
    fi

    local wine_cmd="wine"
    command -v wine64 &>/dev/null && wine_cmd="wine64"

    env WINEPREFIX="${PREFIX}" "${wine_cmd}" reg add \
        'HKEY_CURRENT_USER\Software\Wine\Explorer\Desktops' \
        /v Default /d "${width}x${height}" /f >/dev/null 2>&1

    log "  Wine virtual desktop: ${res}"
}

# Update EQ client VideoMode section
set_eq_resolution() {
    local res="$1"
    local width="${res%%x*}"
    local height="${res##*x}"
    local ini="${PREFIX}/drive_c/EverQuest/eqclient.ini"

    if [[ ! -f "${ini}" ]]; then
        log "  No eqclient.ini found, skipping EQ resolution."
        return 0
    fi

    log "Setting EQ resolution to ${res}..."

    if [[ "${DRY_RUN}" -eq 1 ]]; then
        log "  [DRY-RUN] Would set Width=${width}, Height=${height}"
        return 0
    fi

    # Update [VideoMode] section
    sed -i "s/^Width=.*/Width=${width}/" "${ini}"
    sed -i "s/^Height=.*/Height=${height}/" "${ini}"
    sed -i "s/^WindowedWidth=.*/WindowedWidth=${width}/" "${ini}"
    sed -i "s/^WindowedHeight=.*/WindowedHeight=${height}/" "${ini}"

    log "  EQ VideoMode: ${width}x${height}"
}

# Scale chat window positions for a target resolution
# EQ stores positions per-resolution in UI INIs: XPos1920x1080, YPos1920x1080, etc.
# We generate entries for the target resolution based on proportional scaling
scale_ui_positions() {
    local res="$1"
    local width="${res%%x*}"
    local height="${res##*x}"
    local eq_dir="${PREFIX}/drive_c/EverQuest"

    log "Scaling UI positions for ${res}..."

    # Source resolution for scaling reference
    local src_w=1920
    local src_h=1080

    local count=0
    for ui_file in "${eq_dir}"/UI_*_*.ini; do
        [[ -f "${ui_file}" ]] || continue
        local basename
        basename="$(basename "${ui_file}")"

        if [[ "${DRY_RUN}" -eq 1 ]]; then
            log "  [DRY-RUN] Would scale positions in ${basename}"
            count=$((count + 1))
            continue
        fi

        # Check if this resolution's entries already exist
        if grep -q "XPos${width}x${height}=" "${ui_file}" 2>/dev/null; then
            log "  ${basename}: ${res} positions already exist, skipping."
            count=$((count + 1))
            continue
        fi

        # For each section that has position entries for 1920x1080,
        # generate proportionally scaled entries for the target resolution
        local tmpfile="${ui_file}.tmp"
        cp "${ui_file}" "${tmpfile}"

        # Scale X positions
        while IFS='=' read -r key val; do
            local new_key="${key//${src_w}x${src_h}/${width}x${height}}"
            if [[ "${key}" == *"XPos${src_w}x${src_h}"* ]]; then
                local new_val=$(( val * width / src_w ))
                echo "${new_key}=${new_val}" >> "${tmpfile}"
            elif [[ "${key}" == *"YPos${src_w}x${src_h}"* ]]; then
                local new_val=$(( val * height / src_h ))
                echo "${new_key}=${new_val}" >> "${tmpfile}"
            elif [[ "${key}" == *"Width${src_w}x${src_h}"* ]]; then
                local new_val=$(( val * width / src_w ))
                echo "${new_key}=${new_val}" >> "${tmpfile}"
            elif [[ "${key}" == *"Height${src_w}x${src_h}"* ]]; then
                local new_val=$(( val * height / src_h ))
                echo "${new_key}=${new_val}" >> "${tmpfile}"
            fi
        done < <(grep -E "(XPos|YPos|Width|Height)${src_w}x${src_h}=" "${ui_file}" 2>/dev/null || true)

        mv "${tmpfile}" "${ui_file}"
        log "  ${basename}: scaled positions for ${res}"
        count=$((count + 1))
    done

    if [[ "${count}" -gt 0 ]]; then
        log "  Scaled ${count} UI file(s)."
    fi
}

# Update the norrath-native config with the new resolution
update_config_resolution() {
    local res="$1"
    local config_file="${SCRIPT_DIR}/../norrath-native.yaml"

    if [[ -f "${config_file}" ]]; then
        if grep -q "^resolution:" "${config_file}" 2>/dev/null; then
            if [[ "${DRY_RUN}" -eq 0 ]]; then
                sed -i "s/^resolution:.*/resolution: ${res}/" "${config_file}"
            fi
            log "  Updated norrath-native.yaml resolution to ${res}"
        fi
    fi
}

cmd_detect() {
    local detected
    detected="$(detect_resolution)"
    local current
    current="$(get_current_resolution)"
    local eq_res
    eq_res="$(clamp_to_16x9 "${detected}")"

    printf '\n'
    printf '  Monitor:      %s\n' "${detected}"
    printf '  Wine desktop: %s\n' "${current:-not set}"
    printf '  EQ game res:  %s\n' "${eq_res}"

    if is_ultrawide "${detected}"; then
        printf '\n  Ultrawide detected. Wine desktop will use full %s for tiling.\n' "${detected}"
        printf '  EQ game rendering clamped to %s (16:9) to prevent distortion.\n' "${eq_res}"
        printf '  Use /viewport in-game for centered rendering with UI sidebars.\n'
    fi

    if [[ "${current}" != "${detected}" ]]; then
        printf '\n  Run: make resolution   (to auto-configure)\n'
    else
        printf '\n  Resolution is configured correctly.\n'
    fi
    printf '\n'
}

cmd_apply() {
    shift  # Remove 'apply' from args

    local target_res=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --resolution)
                if [[ $# -lt 2 ]]; then log "ERROR: --resolution requires WxH"; exit 1; fi
                target_res="$2"; shift 2 ;;
            --fullscreen)
                target_res="$(detect_resolution)"; shift ;;
            --prefix)
                if [[ $# -lt 2 ]]; then log "ERROR: --prefix requires a value"; exit 1; fi
                PREFIX="$2"; shift 2 ;;
            --dry-run) DRY_RUN=1; shift ;;
            *) shift ;;
        esac
    done

    # Default: auto-detect
    local monitor_res
    monitor_res="$(detect_resolution)"

    if [[ -z "${target_res}" ]]; then
        target_res="${monitor_res}"
    fi

    local current
    current="$(get_current_resolution)"

    # Wine desktop: full monitor size (for tiling space)
    local wine_res="${monitor_res}"
    # EQ game rendering: clamped to 16:9 (prevents distortion)
    local eq_res
    eq_res="$(clamp_to_16x9 "${target_res}")"

    log "Monitor: ${monitor_res}"
    log "Wine desktop: ${current:-unknown} → ${wine_res} (full monitor for tiling)"
    log "EQ game res:  → ${eq_res} (16:9 clamped)"

    set_wine_resolution "${wine_res}"
    set_eq_resolution "${eq_res}"
    scale_ui_positions "${eq_res}"
    update_config_resolution "${wine_res}"

    if is_ultrawide "${monitor_res}"; then
        local uw_width="${monitor_res%%x*}"
        local eq_width="${eq_res%%x*}"
        local eq_height="${eq_res##*x}"
        local offset=$(( (uw_width - eq_width) / 2 ))
        log ""
        log "ULTRAWIDE: Use this viewport command in-game to center the view:"
        log "  /viewport ${offset} 0 ${eq_width} ${eq_height}"
        log ""
        log "This gives you ${eq_res} centered game rendering with"
        log "${offset}px sidebars on each side for UI elements."
    fi

    log ""
    log "Restart EQ for changes to take effect."
}

# Main dispatch
case "${COMMAND}" in
    detect)
        cmd_detect
        ;;
    apply)
        cmd_apply "$@"
        ;;
    -h|--help)
        usage
        ;;
    *)
        log "Unknown command: ${COMMAND}"
        usage
        ;;
esac
