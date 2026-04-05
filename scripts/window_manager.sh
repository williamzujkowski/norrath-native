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
  identify   Screenshot each window to identify characters
  -h, --help Show this help

Replaces ISBoxer window management on Linux using native X11 tools.
EOF
    exit 0
}

# Detect XWayland coordinate scaling factor.
# On some Wayland compositors, xdotool windowmove doubles the coordinates
# (positions are 2x, sizes are not). We detect this by moving a window
# to a known position and checking what xdotool reports back.
detect_xwayland_scale() {
    local test_wid="${1:-}"
    if [[ -z "${test_wid}" ]]; then
        echo "1"
        return
    fi

    # Move to position 100, check reported position
    DISPLAY=:0 xdotool windowmove "${test_wid}" 100 100 2>/dev/null || true
    local reported_x
    reported_x="$(DISPLAY=:0 xdotool getwindowgeometry "${test_wid}" 2>/dev/null | grep 'Position' | grep -oP '\d+' | head -1 || echo '100')"

    if [[ "${reported_x}" -eq 200 ]]; then
        echo "2"
    else
        echo "1"
    fi
}

# Move and resize an EQ window using Wine's SetWindowPos API.
# This is critical: xdotool windowsize changes the X11 frame but does NOT
# trigger Wine's WM_SIZE message, so EQ won't re-render. SetWindowPos
# sends the proper Windows resize event that makes EQ adapt its rendering.
move_window() {
    local _wid="$1" x="$2" y="$3" w="$4" h="$5"

    # Use Wine's SetWindowPos API via compiled helper
    local helper="${SCRIPT_DIR}/../helpers/wine_resize.exe"
    if [[ -f "${helper}" ]]; then
        WINEPREFIX="${NN_PREFIX}" DISPLAY=:0 wine "${helper}" "${WINE_RESIZE_INDEX}" "${x}" "${y}" "${w}" "${h}" 2>/dev/null || true
        WINE_RESIZE_INDEX=$((WINE_RESIZE_INDEX + 1))
    else
        # Fallback: xdotool (won't trigger re-render but at least positions)
        nn_log "  WARNING: helpers/wine_resize.exe not found, using xdotool fallback"
        nn_log "  Build with: make build-helpers"
        if [[ "${XWAYLAND_SCALE:-1}" -eq 2 ]]; then
            x=$((x / 2))
            y=$((y / 2))
        fi
        DISPLAY=:0 xdotool windowmove "${_wid}" "${x}" "${y}" 2>/dev/null || true
        DISPLAY=:0 xdotool windowsize "${_wid}" "${w}" "${h}" 2>/dev/null || true
    fi
}

WINE_RESIZE_INDEX=0
XWAYLAND_SCALE=1

# Find EQ game windows (exact title match, excludes Discord etc.)
find_eq_windows() {
    nn_find_eq_windows
}

cmd_list() {
    nn_log "Detecting EverQuest windows..."
    local count=0
    while IFS= read -r wid; do
        local name geom
        name="$(DISPLAY=:0 xdotool getwindowname "${wid}" 2>/dev/null || echo 'unknown')"
        geom="$(DISPLAY=:0 xdotool getwindowgeometry "${wid}" 2>/dev/null | grep 'Geometry' | sed 's/.*Geometry: //' || echo '?')"
        printf '  Window %s: %s (%s)\n' "${wid}" "${name}" "${geom}"
        count=$((count + 1))
    done < <(find_eq_windows)

    if [[ "${count}" -eq 0 ]]; then
        nn_log "No EverQuest windows found. Launch first: make launch-multi"
    else
        nn_log "Found ${count} EQ window(s)."
    fi
}

cmd_tile() {
    local -a windows=()
    while IFS= read -r wid; do
        windows+=("${wid}")
    done < <(find_eq_windows)

    local count=${#windows[@]}
    if [[ "${count}" -eq 0 ]]; then
        nn_log "No EverQuest windows found."
        exit 1
    fi

    # Get screen dimensions
    local screen_w screen_h
    screen_w="$(DISPLAY=:0 xdotool getdisplaygeometry 2>/dev/null | cut -d' ' -f1)"
    screen_h="$(DISPLAY=:0 xdotool getdisplaygeometry 2>/dev/null | cut -d' ' -f2)"

    # Detect XWayland coordinate scaling
    XWAYLAND_SCALE="$(detect_xwayland_scale "${windows[0]}")"
    if [[ "${XWAYLAND_SCALE}" -eq 2 ]]; then
        nn_log "XWayland coordinate doubling detected (compensating)."
    fi

    nn_log "Tiling ${count} window(s) on ${screen_w}x${screen_h} display..."

    # Build tile specs for Wine API
    local -a specs=()
    if [[ "${count}" -eq 1 ]]; then
        specs=("0,0,${screen_w}x${screen_h}")
    elif [[ "${count}" -eq 2 ]]; then
        local hw=$((screen_w / 2))
        specs=("0,0,${hw}x${screen_h}" "${hw},0,${hw}x${screen_h}")
    elif [[ "${count}" -le 4 ]]; then
        local hw=$((screen_w / 2))
        local hh=$((screen_h / 2))
        specs=("0,0,${hw}x${hh}" "${hw},0,${hw}x${hh}" "0,${hh},${hw}x${hh}" "${hw},${hh},${hw}x${hh}")
    else
        local tw=$((screen_w / 3))
        local hh=$((screen_h / 2))
        local i
        for (( i=0; i<count && i<6; i++ )); do
            local col=$((i % 3))
            local row=$((i / 3))
            specs+=("$((col * tw)),$((row * hh)),${tw}x${hh}")
        done
    fi

    # Use Wine API for proper resize + re-render
    local helper="${SCRIPT_DIR}/../helpers/wine_helper.exe"
    if [[ -f "${helper}" ]]; then
        WINEPREFIX="${NN_PREFIX}" DISPLAY=:0 wine "${helper}" tile "${specs[@]:0:${count}}" 2>/dev/null
        nn_log "  ${count} windows tiled via Wine API."
    else
        nn_log "  ERROR: helpers/wine_helper.exe not found. Run: make build"
    fi

    nn_log "Done. Use 'make focus-next' to cycle between windows."
}

cmd_pip() {
    local -a windows=()
    while IFS= read -r wid; do
        windows+=("${wid}")
    done < <(find_eq_windows)

    local count=${#windows[@]}
    if [[ "${count}" -lt 2 ]]; then
        nn_log "PiP mode needs 2+ windows."
        exit 1
    fi

    local screen_w screen_h
    screen_w="$(DISPLAY=:0 xdotool getdisplaygeometry 2>/dev/null | cut -d' ' -f1)"
    screen_h="$(DISPLAY=:0 xdotool getdisplaygeometry 2>/dev/null | cut -d' ' -f2)"

    local main_w=$((screen_w * 3 / 4))
    local pip_w=$((screen_w - main_w))
    local pip_h=$((screen_h / (count - 1)))

    local -a specs=("0,0,${main_w}x${screen_h}")
    local i
    for (( i=1; i<count; i++ )); do
        local y=$(( (i - 1) * pip_h ))
        specs+=("${main_w},${y},${pip_w}x${pip_h}")
    done

    local helper="${SCRIPT_DIR}/../helpers/wine_helper.exe"
    if [[ -f "${helper}" ]]; then
        WINEPREFIX="${NN_PREFIX}" DISPLAY=:0 wine "${helper}" tile "${specs[@]}" 2>/dev/null
    fi

    nn_log "PiP: main window + $((count - 1)) side panels."
}

cmd_focus() {
    # Use Wine API for reliable focus switching (SetForegroundWindow)
    local helper="${SCRIPT_DIR}/../helpers/wine_helper.exe"
    if [[ -f "${helper}" ]]; then
        local output
        output="$(WINEPREFIX="${NN_PREFIX}" DISPLAY=:0 wine "${helper}" focus-next 2>/dev/null)"
        nn_log "Focus → ${output}"
        return 0
    fi

    # Fallback: xdotool (less reliable with Wine windows)
    local -a windows=()
    while IFS= read -r wid; do
        windows+=("${wid}")
    done < <(find_eq_windows)

    local count=${#windows[@]}
    if [[ "${count}" -eq 0 ]]; then
        nn_log "No EQ windows found."
        exit 1
    fi

    local active
    active="$(DISPLAY=:0 xdotool getactivewindow 2>/dev/null || echo '0')"

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
    nn_log "Focus → ${name} (window $((next_idx + 1))/${count})"
}

cmd_identify() {
    local -a windows=()
    while IFS= read -r wid; do
        windows+=("${wid}")
    done < <(find_eq_windows)

    local count=${#windows[@]}
    if [[ "${count}" -eq 0 ]]; then
        nn_log "No EQ windows found."
        exit 1
    fi

    nn_log "Identifying ${count} EQ window(s) via log file correlation..."

    local eq_dir="${NN_PREFIX}/drive_c/EverQuest"
    local logs_dir="${eq_dir}/Logs"

    # Build PID→WID mapping sorted by process start time
    local -a sorted_pids=()
    for wid in "${windows[@]}"; do
        local pid
        pid="$(DISPLAY=:0 xdotool getwindowpid "${wid}" 2>/dev/null || echo '0')"
        local start
        start="$(stat -c '%Z' "/proc/${pid}" 2>/dev/null || echo '0')"
        sorted_pids+=("${start}:${pid}:${wid}")
    done
    mapfile -t sorted_pids < <(printf '%s\n' "${sorted_pids[@]}" | sort)

    # Build character login time map from log files
    local -A char_login_time=()
    for logfile in "${logs_dir}"/eqlog_*_*.txt; do
        [[ -f "${logfile}" ]] || continue
        local charname
        charname="$(basename "${logfile}" | sed 's/eqlog_//;s/_[^_]*\.txt//')"
        local login_epoch
        login_epoch="$(grep 'Welcome to EverQuest' "${logfile}" 2>/dev/null | tail -1 | grep -oP '\[.*?\]' | sed 's/[][]//g' | xargs -I{} date -d "{}" '+%s' 2>/dev/null || echo '0')"
        char_login_time["${charname}"]="${login_epoch}"
    done

    # Sort characters by login time
    local -a sorted_chars=()
    for charname in "${!char_login_time[@]}"; do
        sorted_chars+=("${char_login_time[${charname}]}:${charname}")
    done
    mapfile -t sorted_chars < <(printf '%s\n' "${sorted_chars[@]}" | sort)

    # Correlate: process N (by start time) → character N (by login time)
    nn_log ""
    nn_log "Window → Character mapping (by login order):"
    nn_log ""
    local i
    for (( i=0; i<count && i<${#sorted_chars[@]}; i++ )); do
        local proc_info="${sorted_pids[${i}]}"
        local char_info="${sorted_chars[${i}]}"
        local pid="${proc_info#*:}" && pid="${pid%%:*}"
        local wid="${proc_info##*:}"
        local charname="${char_info#*:}"
        local geom
        geom="$(DISPLAY=:0 xdotool getwindowgeometry "${wid}" 2>/dev/null | grep 'Geometry' | sed 's/.*Geometry: //' || echo '?')"
        nn_log "  Window $((i+1)): ${charname} (WID ${wid}, PID ${pid}, ${geom})"
    done

    nn_log ""
    nn_log "This mapping is based on process start time → login timestamp"
    nn_log "correlation from eqlog_*_*.txt files."
}

# Parse command
case "${COMMAND}" in
    tile)     cmd_tile ;;
    focus)    cmd_focus ;;
    list)     cmd_list ;;
    pip)      cmd_pip ;;
    identify) cmd_identify ;;
    -h|--help) usage ;;
    *)
        nn_log "Unknown command: ${COMMAND}"
        usage
        ;;
esac
