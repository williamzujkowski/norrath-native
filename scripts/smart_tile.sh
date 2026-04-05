#!/usr/bin/env bash
set -euo pipefail

# smart_tile.sh — Tile EQ windows by character identity using Wine API
#
# Uses wine_helper.exe map to get HWND→X11 WID mapping, then
# correlates X11 WID→PID→character via login timestamps.
# Tiles by character role (main=large, box=small) using Wine's
# SetWindowPos for proper re-rendering.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config_reader.sh
source "${SCRIPT_DIR}/config_reader.sh"

PREFIX="${NN_PREFIX}"
TEMPLATE="${1:-auto}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [TEMPLATE] [OPTIONS]

Tile EQ windows by character role (main=large, box=small).
Automatically identifies which character is in which window.

Templates:
  auto              Main-left layout (default)
  equal             Equal grid for all windows

Options:
  --main NAME       Override which character is main (default: from config)
  --prefix PATH     Override WINEPREFIX
  -h, --help        Show this help
EOF
    exit 0
}

main() {
    local main_char="${NN_MAIN_CHARACTER}"
    shift || true

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --main)
                if [[ $# -lt 2 ]]; then nn_log "ERROR: --main requires a name"; exit 1; fi
                main_char="$2"; shift 2 ;;
            --prefix)
                if [[ $# -lt 2 ]]; then nn_log "ERROR: --prefix requires a value"; exit 1; fi
                PREFIX="$2"; shift 2 ;;
            -h|--help) usage ;;
            *) shift ;;
        esac
    done

    local helper="${SCRIPT_DIR}/../helpers/wine_helper.exe"
    if [[ ! -f "${helper}" ]]; then
        nn_log "ERROR: helpers/wine_helper.exe not found. Run: make build"
        exit 1
    fi

    # Get screen size
    local screen_w screen_h
    screen_w="$(DISPLAY=:0 xdotool getdisplaygeometry 2>/dev/null | cut -d' ' -f1)"
    screen_h="$(DISPLAY=:0 xdotool getdisplaygeometry 2>/dev/null | cut -d' ' -f2)"
    nn_log "Screen: ${screen_w}x${screen_h}"

    # Get HWND→X11 WID mapping from Wine
    nn_log "Mapping windows via Wine API..."
    local -a hwnd_list=()
    local -a x11wid_list=()
    while IFS='|' read -r _idx hwnd _pos _size _wpid x11wid; do
        hwnd_list+=("${hwnd}")
        x11wid_list+=("${x11wid}")
    done < <(WINEPREFIX="${PREFIX}" DISPLAY=:0 wine "${helper}" map 2>/dev/null)

    local count=${#hwnd_list[@]}
    if [[ "${count}" -eq 0 ]]; then
        nn_log "ERROR: No EQ windows found via Wine API."
        exit 1
    fi

    # Map X11 WID→PID→character via sorted login timestamp correlation
    nn_log "Identifying characters..."

    # Build sorted list of (process_start, hwnd_index) for Wine windows
    local -a proc_entries=()
    local i
    for (( i=0; i<count; i++ )); do
        local x11wid="${x11wid_list[i]}"
        local pid
        pid="$(DISPLAY=:0 xdotool getwindowpid "${x11wid}" 2>/dev/null || echo '0')"
        local proc_start
        proc_start="$(stat -c '%Z' "/proc/${pid}" 2>/dev/null || echo '0')"
        proc_entries+=("${proc_start}:${i}")
    done
    mapfile -t proc_entries < <(printf '%s\n' "${proc_entries[@]}" | sort -n)

    # Build sorted list of (login_time, char_name)
    local -a char_entries=()
    local eq_dir="${PREFIX}/drive_c/EverQuest"
    for logfile in "${eq_dir}"/Logs/eqlog_*_*.txt; do
        [[ -f "${logfile}" ]] || continue
        local cname
        cname="$(basename "${logfile}" | sed 's/eqlog_//;s/_[^_]*\.txt//')"
        local login_epoch
        login_epoch="$(grep 'Welcome to EverQuest' "${logfile}" 2>/dev/null | tail -1 | grep -oP '\[.*?\]' | sed 's/[][]//g' | xargs -I{} date -d '{}' '+%s' 2>/dev/null || echo '0')"
        if [[ "${login_epoch}" -gt 0 ]]; then
            char_entries+=("${login_epoch}:${cname}")
        fi
    done
    mapfile -t char_entries < <(printf '%s\n' "${char_entries[@]}" | sort -n)

    # Match 1:1 by sorted position (1st process = 1st login, etc.)
    local -a char_names=()
    for (( i=0; i<count; i++ )); do
        char_names+=("unknown")
    done

    local match_count=${#proc_entries[@]}
    if [[ ${#char_entries[@]} -lt ${match_count} ]]; then
        match_count=${#char_entries[@]}
    fi

    for (( i=0; i<match_count; i++ )); do
        local hwnd_idx="${proc_entries[i]##*:}"
        local cname="${char_entries[i]##*:}"
        char_names[hwnd_idx]="${cname}"
        nn_log "  ${cname} → HWND ${hwnd_list[hwnd_idx]}"
    done

    # Find main character index
    local main_idx=0
    if [[ -n "${main_char}" ]]; then
        for (( i=0; i<count; i++ )); do
            if [[ "${char_names[i]}" == "${main_char}" ]]; then
                main_idx=${i}
                break
            fi
        done
    fi
    nn_log ""
    nn_log "Main: ${char_names[main_idx]}"

    # Build tile specs: main gets 65% left, boxes stack right
    local -a tile_args=()

    if [[ "${count}" -eq 1 ]] || [[ "${TEMPLATE}" == "solo" ]]; then
        tile_args+=("0x${hwnd_list[0]}" "0,0,${screen_w}x${screen_h}")
    elif [[ "${TEMPLATE}" == "equal" ]]; then
        local hw=$((screen_w / 2))
        local hh=$((screen_h / 2))
        local positions=("0,0,${hw}x${hh}" "${hw},0,${hw}x${hh}" "0,${hh},${hw}x${hh}" "${hw},${hh},${hw}x${hh}")
        for (( i=0; i<count && i<4; i++ )); do
            tile_args+=("0x${hwnd_list[i]}" "${positions[i]}")
        done
    else
        # Main-left layout
        local main_w=$((screen_w * 65 / 100))
        local box_w=$((screen_w - main_w))
        local box_count=$((count - 1))
        if [[ "${box_count}" -lt 1 ]]; then box_count=1; fi
        local box_h=$((screen_h / box_count))

        # Main character gets the big window (prefix HWND with 0x for C parsing)
        tile_args+=("0x${hwnd_list[main_idx]}" "0,0,${main_w}x${screen_h}")
        nn_log "  ${char_names[main_idx]}: (0,0) ${main_w}x${screen_h} [MAIN]"

        # Boxes stack on the right
        local box_i=0
        for (( i=0; i<count; i++ )); do
            if [[ "${i}" -ne "${main_idx}" ]]; then
                local y=$((box_i * box_h))
                tile_args+=("0x${hwnd_list[i]}" "${main_w},${y},${box_w}x${box_h}")
                nn_log "  ${char_names[i]}: (${main_w},${y}) ${box_w}x${box_h}"
                box_i=$((box_i + 1))
            fi
        done
    fi

    # Apply via Wine API (SetWindowPos for each HWND)
    nn_log ""
    nn_log "Applying via Wine API..."
    WINEPREFIX="${PREFIX}" DISPLAY=:0 wine "${helper}" tile-hwnd "${tile_args[@]}" 2>/dev/null

    nn_log ""
    nn_log "Tiling complete. ${char_names[main_idx]} is the main window."
}

TEMPLATE="${1:-auto}"
main "$@"
