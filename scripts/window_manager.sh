#!/usr/bin/env bash
set -euo pipefail

# window_manager.sh — Arrange and cycle EverQuest windows for multiboxing
#
# Replaces ISBoxer's window layout and focus-switching on Linux using
# native X11 tools (wmctrl, xdotool). No paid software needed.
#
# Commands:
#   tile   — Arrange EQ windows in a grid layout
#   focus  — Cycle focus to the next EQ window
#   list   — Show all EQ windows with IDs

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config_reader.sh
source "${SCRIPT_DIR}/config_reader.sh"

COMMAND="${1:-help}"

usage() {
    cat <<EOF
Usage: $(basename "$0") <command>

Manage EverQuest windows for multiboxing.

Commands:
  tile       Arrange all EQ windows in a grid layout
  focus      Cycle focus to the next EQ window
  list       Show all detected EQ windows
  pip        Picture-in-picture: main window large, others small
  -h, --help Show this help

Replaces ISBoxer window management on Linux using native X11 tools.
EOF
    exit 0
}

log() {
    printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

# Find all EverQuest windows (Wine virtual desktops running EQ)
find_eq_windows() {
    local -a windows=()
    while IFS= read -r wid; do
        windows+=("${wid}")
    done < <(DISPLAY=:0 xdotool search --name "Default - Wine desktop" 2>/dev/null || true)

    # Also check for direct EQ windows
    while IFS= read -r wid; do
        windows+=("${wid}")
    done < <(DISPLAY=:0 xdotool search --name "EverQuest" 2>/dev/null || true)

    # Deduplicate
    printf '%s\n' "${windows[@]}" | sort -u
}

cmd_list() {
    log "Detecting EverQuest windows..."
    local count=0
    while IFS= read -r wid; do
        local name geom
        name="$(DISPLAY=:0 xdotool getwindowname "${wid}" 2>/dev/null || echo 'unknown')"
        geom="$(DISPLAY=:0 xdotool getwindowgeometry "${wid}" 2>/dev/null | grep 'Geometry' | sed 's/.*Geometry: //' || echo '?')"
        printf '  Window %s: %s (%s)\n' "${wid}" "${name}" "${geom}"
        count=$((count + 1))
    done < <(find_eq_windows)

    if [[ "${count}" -eq 0 ]]; then
        log "No EverQuest windows found. Launch first: make launch-multi"
    else
        log "Found ${count} EQ window(s)."
    fi
}

cmd_tile() {
    local -a windows=()
    while IFS= read -r wid; do
        windows+=("${wid}")
    done < <(find_eq_windows)

    local count=${#windows[@]}
    if [[ "${count}" -eq 0 ]]; then
        log "No EverQuest windows found."
        exit 1
    fi

    # Get screen dimensions
    local screen_w screen_h
    screen_w="$(DISPLAY=:0 xdotool getdisplaygeometry 2>/dev/null | cut -d' ' -f1)"
    screen_h="$(DISPLAY=:0 xdotool getdisplaygeometry 2>/dev/null | cut -d' ' -f2)"

    log "Tiling ${count} window(s) on ${screen_w}x${screen_h} display..."

    if [[ "${count}" -eq 1 ]]; then
        # Single window: maximize
        DISPLAY=:0 wmctrl -i -r "${windows[0]}" -e "0,0,0,${screen_w},${screen_h}" 2>/dev/null
        log "  Window maximized."
    elif [[ "${count}" -eq 2 ]]; then
        # Two windows: side by side
        local half_w=$((screen_w / 2))
        DISPLAY=:0 wmctrl -i -r "${windows[0]}" -e "0,0,0,${half_w},${screen_h}" 2>/dev/null
        DISPLAY=:0 wmctrl -i -r "${windows[1]}" -e "0,${half_w},0,${half_w},${screen_h}" 2>/dev/null
        log "  2 windows: side-by-side."
    elif [[ "${count}" -le 4 ]]; then
        # 3-4 windows: 2x2 grid
        local half_w=$((screen_w / 2))
        local half_h=$((screen_h / 2))
        local positions=("0,0" "${half_w},0" "0,${half_h}" "${half_w},${half_h}")
        local i
        for (( i=0; i<count; i++ )); do
            local x y
            x="$(echo "${positions[${i}]}" | cut -d, -f1)"
            y="$(echo "${positions[${i}]}" | cut -d, -f2)"
            DISPLAY=:0 wmctrl -i -r "${windows[${i}]}" -e "0,${x},${y},${half_w},${half_h}" 2>/dev/null
        done
        log "  ${count} windows: 2x2 grid."
    else
        # 5-6 windows: 3x2 grid
        local third_w=$((screen_w / 3))
        local half_h=$((screen_h / 2))
        local i
        for (( i=0; i<count; i++ )); do
            local col=$((i % 3))
            local row=$((i / 3))
            local x=$((col * third_w))
            local y=$((row * half_h))
            DISPLAY=:0 wmctrl -i -r "${windows[${i}]}" -e "0,${x},${y},${third_w},${half_h}" 2>/dev/null
        done
        log "  ${count} windows: 3x2 grid."
    fi

    log "Done. Use 'make focus-next' to cycle between windows."
}

cmd_pip() {
    local -a windows=()
    while IFS= read -r wid; do
        windows+=("${wid}")
    done < <(find_eq_windows)

    local count=${#windows[@]}
    if [[ "${count}" -lt 2 ]]; then
        log "PiP mode needs 2+ windows."
        exit 1
    fi

    local screen_w screen_h
    screen_w="$(DISPLAY=:0 xdotool getdisplaygeometry 2>/dev/null | cut -d' ' -f1)"
    screen_h="$(DISPLAY=:0 xdotool getdisplaygeometry 2>/dev/null | cut -d' ' -f2)"

    # Main window: 75% of screen
    local main_w=$((screen_w * 3 / 4))
    DISPLAY=:0 wmctrl -i -r "${windows[0]}" -e "0,0,0,${main_w},${screen_h}" 2>/dev/null

    # Others: stacked in the right 25%
    local pip_w=$((screen_w - main_w))
    local pip_h=$((screen_h / (count - 1)))
    local i
    for (( i=1; i<count; i++ )); do
        local y=$(( (i - 1) * pip_h ))
        DISPLAY=:0 wmctrl -i -r "${windows[${i}]}" -e "0,${main_w},${y},${pip_w},${pip_h}" 2>/dev/null
    done

    log "PiP: main window + ${count} side panels."
}

cmd_focus() {
    local -a windows=()
    while IFS= read -r wid; do
        windows+=("${wid}")
    done < <(find_eq_windows)

    local count=${#windows[@]}
    if [[ "${count}" -eq 0 ]]; then
        log "No EQ windows found."
        exit 1
    fi

    # Find currently focused window
    local active
    active="$(DISPLAY=:0 xdotool getactivewindow 2>/dev/null || echo '0')"

    # Find its index and go to the next one
    local next_idx=0
    local i
    for (( i=0; i<count; i++ )); do
        if [[ "${windows[${i}]}" == "${active}" ]]; then
            next_idx=$(( (i + 1) % count ))
            break
        fi
    done

    local next_wid="${windows[${next_idx}]}"
    DISPLAY=:0 xdotool windowactivate --sync "${next_wid}" 2>/dev/null

    local name
    name="$(DISPLAY=:0 xdotool getwindowname "${next_wid}" 2>/dev/null || echo 'EQ')"
    log "Focus → ${name} (window $((next_idx + 1))/${count})"
}

# Parse command
case "${COMMAND}" in
    tile)     cmd_tile ;;
    focus)    cmd_focus ;;
    list)     cmd_list ;;
    pip)      cmd_pip ;;
    -h|--help) usage ;;
    *)
        log "Unknown command: ${COMMAND}"
        usage
        ;;
esac
