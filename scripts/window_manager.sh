#!/usr/bin/env bash
set -euo pipefail

# window_manager.sh — Arrange and cycle EverQuest windows for multiboxing
#
# All window operations use Wine's native Windows API (via wine_helper.exe)
# for reliable positioning, resizing, and focus management. xdotool is NOT
# used — it disrupts Wine's internal input routing.
#
# Commands:
#   tile   — Arrange EQ windows in a grid layout
#   focus  — Cycle focus to the next EQ window
#   list   — Show all EQ windows with IDs

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config_reader.sh
source "${SCRIPT_DIR}/config_reader.sh"

COMMAND="${1:-help}"
HELPER="${SCRIPT_DIR}/../helpers/wine_helper.exe"

usage() {
    cat <<EOF
Usage: $(basename "$0") <command>

Manage EverQuest windows for multiboxing.

Commands:
  tile       Arrange all EQ windows in a grid layout
  focus      Cycle focus to the next EQ window
  list       Show all detected EQ windows
  pip        Picture-in-picture: main window large, others small
  identify   Identify which character is in which window
  -h, --help Show this help

All operations use Wine's native API for reliable focus/input handling.
EOF
    exit 0
}

require_helper() {
    if [[ ! -f "${HELPER}" ]]; then
        nn_log "ERROR: helpers/wine_helper.exe not found. Run: make build"
        exit 1
    fi
}

cmd_list() {
    require_helper
    nn_log "Detecting EverQuest windows..."
    local count=0
    while IFS='|' read -r idx hwnd pos size pid; do
        printf '  Window %s: HWND %s at %s size %s (Wine PID %s)\n' "${idx}" "${hwnd}" "${pos}" "${size}" "${pid}"
        count=$((count + 1))
    done < <(WINEPREFIX="${NN_PREFIX}" DISPLAY=:0 wine "${HELPER}" find 2>/dev/null)

    if [[ "${count}" -eq 0 ]]; then
        nn_log "No EverQuest windows found. Launch first: make launch-multi"
    else
        nn_log "Found ${count} EQ window(s)."
    fi
}

cmd_tile() {
    require_helper

    local count
    count="$(WINEPREFIX="${NN_PREFIX}" DISPLAY=:0 wine "${HELPER}" find 2>/dev/null | wc -l)"
    if [[ "${count}" -eq 0 ]]; then
        nn_log "No EverQuest windows found."
        exit 1
    fi

    # Get screen dimensions (uses Wine virtual desktop if configured)
    local screen_w screen_h
    read -r screen_w screen_h <<< "$(nn_get_screen_size)"

    nn_log "Tiling ${count} window(s) on ${screen_w}x${screen_h} display..."

    # Build tile specs — offset from origin to avoid Wine desktop click interception
    local ox=1 oy=1
    local -a specs=()
    if [[ "${count}" -eq 1 ]]; then
        specs=("${ox},${oy},$((screen_w - ox))x$((screen_h - oy))")
    elif [[ "${count}" -eq 2 ]]; then
        local hw=$((screen_w / 2))
        specs=("${ox},${oy},$((hw - ox))x$((screen_h - oy))" "${hw},0,${hw}x${screen_h}")
    elif [[ "${count}" -le 4 ]]; then
        local hw=$((screen_w / 2))
        local hh=$((screen_h / 2))
        specs=("${ox},${oy},$((hw - ox))x$((hh - oy))" "${hw},${oy},$((hw))x$((hh - oy))" "${ox},${hh},$((hw - ox))x${hh}" "${hw},${hh},${hw}x${hh}")
    else
        local tw=$((screen_w / 3))
        local hh=$((screen_h / 2))
        local i
        for (( i=0; i<count && i<6; i++ )); do
            local col=$((i % 3))
            local row=$((i / 3))
            local x=$((col * tw))
            local y=$((row * hh))
            if [[ "${x}" -eq 0 ]] && [[ "${y}" -eq 0 ]]; then
                specs+=("${ox},${oy},$((tw - ox))x$((hh - oy))")
            else
                specs+=("${x},${y},${tw}x${hh}")
            fi
        done
    fi

    WINEPREFIX="${NN_PREFIX}" DISPLAY=:0 wine "${HELPER}" tile "${specs[@]:0:${count}}" 2>/dev/null
    nn_log "  ${count} windows tiled via Wine API."
    nn_log "Done. Use 'make focus-next' to cycle between windows."
}

cmd_pip() {
    require_helper

    local count
    count="$(WINEPREFIX="${NN_PREFIX}" DISPLAY=:0 wine "${HELPER}" find 2>/dev/null | wc -l)"
    if [[ "${count}" -lt 2 ]]; then
        nn_log "PiP mode needs 2+ windows."
        exit 1
    fi

    local screen_w screen_h
    read -r screen_w screen_h <<< "$(nn_get_screen_size)"

    local main_w=$((screen_w * 3 / 4))
    local pip_w=$((screen_w - main_w))
    local pip_h=$((screen_h / (count - 1)))

    # Offset main window from origin
    local -a specs=("1,1,$((main_w - 1))x$((screen_h - 1))")
    local i
    for (( i=1; i<count; i++ )); do
        local y=$(( (i - 1) * pip_h ))
        specs+=("${main_w},${y},${pip_w}x${pip_h}")
    done

    WINEPREFIX="${NN_PREFIX}" DISPLAY=:0 wine "${HELPER}" tile "${specs[@]}" 2>/dev/null
    nn_log "PiP: main window + $((count - 1)) side panels."
}

cmd_focus() {
    require_helper
    local output
    output="$(WINEPREFIX="${NN_PREFIX}" DISPLAY=:0 wine "${HELPER}" focus-next 2>/dev/null)"
    nn_log "Focus → ${output}"
}

cmd_identify() {
    require_helper
    nn_log "Identifying EQ windows via Wine API + log correlation..."

    local eq_dir="${NN_PREFIX}/drive_c/EverQuest"

    # Get Wine map data: idx|hwnd|pos|size|wine_pid|x11wid
    local -a hwnd_list=()
    local -a x11wid_list=()
    while IFS='|' read -r _idx hwnd _pos _size _wpid x11wid; do
        hwnd_list+=("${hwnd}")
        x11wid_list+=("${x11wid}")
    done < <(WINEPREFIX="${NN_PREFIX}" DISPLAY=:0 wine "${HELPER}" map 2>/dev/null)

    local count=${#hwnd_list[@]}
    if [[ "${count}" -eq 0 ]]; then
        nn_log "No EQ windows found."
        exit 1
    fi

    # Get Linux PIDs via xprop, sort by process start time
    local -a proc_entries=()
    local i
    for (( i=0; i<count; i++ )); do
        local pid
        pid="$(DISPLAY=:0 xprop -id "${x11wid_list[i]}" _NET_WM_PID 2>/dev/null | grep -oP '\d+$' || echo '0')"
        local start
        start="$(stat -c '%Z' "/proc/${pid}" 2>/dev/null || echo '0')"
        proc_entries+=("${start}:${pid}:${i}")
    done
    mapfile -t proc_entries < <(printf '%s\n' "${proc_entries[@]}" | sort -n)

    # Sort characters by login time from eqlog files
    local now
    now="$(date '+%s')"
    local -a char_entries=()
    for logfile in "${eq_dir}"/Logs/eqlog_*_*.txt; do
        [[ -f "${logfile}" ]] || continue
        local cname
        cname="$(basename "${logfile}" | sed 's/eqlog_//;s/_[^_]*\.txt//')"
        local login_epoch
        login_epoch="$(grep 'Welcome to EverQuest' "${logfile}" 2>/dev/null | tail -1 | grep -oP '\[.*?\]' | sed 's/[][]//g' | xargs -I{} date -d '{}' '+%s' 2>/dev/null || echo '0')"
        if [[ "${login_epoch}" -gt 0 ]] && [[ $((now - login_epoch)) -lt 43200 ]]; then
            char_entries+=("${login_epoch}:${cname}")
        fi
    done
    mapfile -t char_entries < <(printf '%s\n' "${char_entries[@]}" | sort -n)

    # Match by sorted position
    nn_log ""
    nn_log "Window → Character mapping:"
    nn_log ""
    local match_count=${#proc_entries[@]}
    if [[ ${#char_entries[@]} -lt ${match_count} ]]; then
        match_count=${#char_entries[@]}
    fi

    for (( i=0; i<match_count; i++ )); do
        local proc_info="${proc_entries[i]}"
        local idx="${proc_info##*:}"
        local pid="${proc_info#*:}" && pid="${pid%%:*}"
        local cname="${char_entries[i]##*:}"
        nn_log "  Window $((i+1)): ${cname} (HWND ${hwnd_list[idx]}, PID ${pid})"
    done

    nn_log ""
    nn_log "Main character: ${NN_MAIN_CHARACTER:-not set}"
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
