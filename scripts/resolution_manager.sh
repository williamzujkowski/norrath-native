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

Commands:
  detect             Show detected primary monitor resolution
  apply              Set Wine + EQ to detected resolution (or --resolution WxH)
  apply --resolution WxH   Set a specific resolution
  apply --fullscreen       Match primary monitor exactly

Options:
  --prefix PATH      Override WINEPREFIX
  --dry-run          Preview changes without writing
  -h, --help         Show this help

Examples:
  $(basename "$0") detect                    # Show monitor size
  $(basename "$0") apply                     # Auto-fill monitor
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

    printf '\n'
    printf '  Monitor:  %s\n' "${detected}"
    printf '  Wine:     %s\n' "${current:-not set}"

    if [[ "${detected}" != "${current}" ]]; then
        printf '\n  Wine resolution does not match your monitor.\n'
        printf '  Run: make resolution   (to auto-match)\n'
    else
        printf '\n  Resolution matches your monitor.\n'
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
    if [[ -z "${target_res}" ]]; then
        target_res="$(detect_resolution)"
    fi

    local current
    current="$(get_current_resolution)"

    log "Resolution change: ${current:-unknown} → ${target_res}"

    set_wine_resolution "${target_res}"
    set_eq_resolution "${target_res}"
    scale_ui_positions "${target_res}"
    update_config_resolution "${target_res}"

    log ""
    log "Resolution set to ${target_res}."
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
