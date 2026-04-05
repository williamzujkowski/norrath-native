#!/usr/bin/env bash
set -euo pipefail

# adapt_display.sh — Auto-adapt to current display resolution
#
# Run after plugging/unplugging a monitor, or switching between
# laptop screen and external display. Detects the current primary
# monitor and updates Wine, EQ, and window layout to match.
#
# Safe to run while EQ is running — uses Wine API for live resize.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config_reader.sh
source "${SCRIPT_DIR}/config_reader.sh"

PREFIX="${NN_PREFIX}"
DRY_RUN=0

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Auto-adapt to the current display. Detects your primary monitor
and updates Wine virtual desktop, EQ resolution, and window tiling.

Safe to run while EQ is running.

Options:
  --prefix PATH   Override WINEPREFIX
  --dry-run       Preview changes without applying
  -h, --help      Show this help

Examples:
  $(basename "$0")            # Auto-detect and adapt
  $(basename "$0") --dry-run  # Preview what would change
EOF
    exit 0
}

detect_display() {
    local res
    res="$(DISPLAY=:0 xrandr 2>/dev/null | grep ' connected primary' | grep -oP '\d+x\d+' | head -1 || true)"
    if [[ -z "${res}" ]]; then
        res="$(DISPLAY=:0 xrandr 2>/dev/null | grep ' connected' | grep -oP '\d+x\d+' | head -1 || true)"
    fi
    if [[ -z "${res}" ]]; then
        res="1920x1080"
    fi
    printf '%s' "${res}"
}

get_current_wine_res() {
    grep '"Default"=' "${PREFIX}/user.reg" 2>/dev/null | grep -oP '\d+x\d+' | head -1 || echo 'unknown'
}

is_ultrawide() {
    local res="$1"
    local w="${res%%x*}"
    local h="${res##*x}"
    local ratio
    ratio="$(echo "${w} ${h}" | awk '{printf "%.2f", $1/$2}')"
    awk "BEGIN {exit !(${ratio} > 1.78)}" 2>/dev/null
}

clamp_16x9() {
    local res="$1"
    local w="${res%%x*}"
    local h="${res##*x}"
    if is_ultrawide "${res}"; then
        local clamped=$((h * 16 / 9))
        printf '%dx%d' "${clamped}" "${h}"
    else
        printf '%s' "${res}"
    fi
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

    local monitor_res
    monitor_res="$(detect_display)"
    local current_wine
    current_wine="$(get_current_wine_res)"
    local eq_res
    eq_res="$(clamp_16x9 "${monitor_res}")"

    nn_log "=== Display Adaptation ==="
    nn_log "  Monitor:      ${monitor_res}"
    nn_log "  Wine desktop: ${current_wine}"
    nn_log "  EQ game res:  ${eq_res}"

    if [[ "${current_wine}" == "${monitor_res}" ]]; then
        nn_log ""
        nn_log "Already matched. No changes needed."
        return 0
    fi

    nn_log ""
    nn_log "Adapting: ${current_wine} → ${monitor_res}"

    if [[ "${DRY_RUN}" -eq 1 ]]; then
        nn_log ""
        nn_log "[DRY-RUN] Would update:"
        nn_log "  Wine virtual desktop → ${monitor_res}"
        nn_log "  EQ VideoMode → ${eq_res}"
        if is_ultrawide "${monitor_res}"; then
            local offset=$(( (${monitor_res%%x*} - ${eq_res%%x*}) / 2 ))
            nn_log "  Viewport: /viewport ${offset} 0 ${eq_res%%x*} ${eq_res##*x}"
        fi
        nn_log "  UI positions → scaled for ${eq_res}"
        if nn_is_eq_running; then
            nn_log "  Running windows → re-tiled via Wine API"
        fi
        return 0
    fi

    # Step 1: Update Wine virtual desktop
    nn_log ""
    nn_log "Step 1: Wine virtual desktop → ${monitor_res}"
    "${NN_WINE_CMD}" reg add \
        'HKEY_CURRENT_USER\Software\Wine\Explorer\Desktops' \
        /v Default /d "${monitor_res%%x*}x${monitor_res##*x}" /f >/dev/null 2>&1

    # Step 2: Update EQ resolution
    nn_log "Step 2: EQ resolution → ${eq_res}"
    local ini="${PREFIX}/drive_c/EverQuest/eqclient.ini"
    if [[ -f "${ini}" ]]; then
        sed -i "s/^Width=.*/Width=${eq_res%%x*}/" "${ini}"
        sed -i "s/^Height=.*/Height=${eq_res##*x}/" "${ini}"
        sed -i "s/^WindowedWidth=.*/WindowedWidth=${eq_res%%x*}/" "${ini}"
        sed -i "s/^WindowedHeight=.*/WindowedHeight=${eq_res##*x}/" "${ini}"
    fi

    # Step 3: Scale UI positions
    nn_log "Step 3: Scaling UI positions for ${eq_res}"
    bash "${SCRIPT_DIR}/resolution_manager.sh" apply --resolution "${monitor_res}" 2>/dev/null || true

    # Step 4: Re-tile running windows if EQ is active
    # Uses smart_tile.sh for character-aware tiling (main char gets big window)
    if nn_is_eq_running; then
        nn_log "Step 4: Re-tiling running windows via smart_tile"
        local eq_count
        eq_count="$(nn_find_eq_windows | wc -l)"

        if [[ "${eq_count}" -gt 0 ]]; then
            bash "${SCRIPT_DIR}/smart_tile.sh" auto --prefix "${PREFIX}"
            nn_log "  Re-tiled ${eq_count} window(s) with character identification"
        else
            nn_log "  No EQ windows found to re-tile"
        fi
    else
        nn_log "Step 4: EQ not running — tiling will apply on next launch"
    fi

    # Step 5: Show viewport command if ultrawide
    if is_ultrawide "${monitor_res}"; then
        local uw_w="${monitor_res%%x*}"
        local eq_w="${eq_res%%x*}"
        local eq_h="${eq_res##*x}"
        local offset=$(( (uw_w - eq_w) / 2 ))
        nn_log ""
        nn_log "ULTRAWIDE: Run in-game on each character:"
        nn_log "  /viewport ${offset} 0 ${eq_w} ${eq_h}"
    else
        nn_log ""
        nn_log "Standard 16:9 — no viewport adjustment needed."
        nn_log "  If you previously set a viewport, reset with: /viewport reset"
    fi

    nn_log ""
    nn_log "Display adaptation complete."
    if ! nn_is_eq_running; then
        nn_log "Restart EQ for resolution changes to take effect."
    fi
}

main "$@"
