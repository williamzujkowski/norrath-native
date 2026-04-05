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
    local main_index=""
    shift || true

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --main)
                if [[ $# -lt 2 ]]; then nn_log "ERROR: --main requires a name"; exit 1; fi
                main_char="$2"; shift 2 ;;
            --main-index)
                if [[ $# -lt 2 ]]; then nn_log "ERROR: --main-index requires a number"; exit 1; fi
                main_index="$2"; shift 2 ;;
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

    # Get screen size (physical monitor — no virtual desktop)
    local screen_w screen_h
    read -r screen_w screen_h <<< "$(nn_get_screen_size)"
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

    # Character identification is not reliable — timestamp correlation
    # breaks when characters log in within seconds of each other, and
    # EQ doesn't expose character names via window titles or open files.
    #
    # Instead: tile all windows first, then if --main-index N is given
    # (or auto-detected on subsequent runs), swap that window to main.
    # On first run, window 0 gets main. User can re-run with:
    #   make tile   (then visually check which is which)
    #   smart_tile.sh --main-index 2  (swap window 2 to main)
    nn_log "Windows found: ${count}"

    local -a char_names=()
    local i
    for (( i=0; i<count; i++ )); do
        char_names+=("window-${i}")
    done

    # Determine which window gets the main (big) position.
    # Priority: --main-index flag > saved mapping > default (0)
    local main_idx=0
    local state_dir="${HOME}/.local/share/norrath-native"
    local hwnd_map="${state_dir}/hwnd-character-map"

    if [[ -n "${main_index}" ]]; then
        # User explicitly specified which window index is main
        main_idx="${main_index}"
        nn_log "Main: window ${main_idx} (--main-index)"
    elif [[ -n "${main_char}" ]] && [[ -f "${hwnd_map}" ]]; then
        # Check saved HWND→character mapping from previous identification
        for (( i=0; i<count; i++ )); do
            local saved_char
            saved_char="$(grep "^${hwnd_list[i]}=" "${hwnd_map}" 2>/dev/null | cut -d= -f2 || echo '')"
            if [[ "${saved_char}" == "${main_char}" ]]; then
                main_idx=${i}
                char_names[i]="${saved_char}"
                nn_log "Main: ${saved_char} → window ${i} (saved mapping)"
                break
            fi
        done
    else
        nn_log "Main: window ${main_idx} (default)"
    fi

    nn_log "  Use 'make tile-set-main' after visually identifying your main character."

    # Build tile specs.
    # For ultrawide monitors, clamp the main window to 16:9 aspect ratio
    # (EQ's max). Remaining space goes to box windows.
    local main_w
    local aspect_ratio
    aspect_ratio="$(echo "${screen_w} ${screen_h}" | awk '{printf "%.2f", $1/$2}')"
    if awk "BEGIN {exit !(${aspect_ratio} > 1.78)}" 2>/dev/null; then
        # Ultrawide: main gets 16:9 clamped width
        main_w=$((screen_h * 16 / 9))
        nn_log "Ultrawide detected — main window clamped to ${main_w}x${screen_h} (16:9)"
    else
        # Standard: main gets 65%
        main_w=$((screen_w * 65 / 100))
    fi

    local -a tile_args=()

    if [[ "${count}" -eq 1 ]] || [[ "${TEMPLATE}" == "solo" ]]; then
        tile_args+=("0x${hwnd_list[0]}" "0,0,${main_w}x${screen_h}")
    elif [[ "${TEMPLATE}" == "equal" ]]; then
        local hw=$((screen_w / 2))
        local hh=$((screen_h / 2))
        local positions=("0,0,${hw}x${hh}" "${hw},0,${hw}x${hh}" "0,${hh},${hw}x${hh}" "${hw},${hh},${hw}x${hh}")
        for (( i=0; i<count && i<4; i++ )); do
            tile_args+=("0x${hwnd_list[i]}" "${positions[i]}")
        done
    else
        # Main-left layout
        local box_w=$((screen_w - main_w))
        local box_count=$((count - 1))
        if [[ "${box_count}" -lt 1 ]]; then box_count=1; fi
        local box_h=$((screen_h / box_count))

        # Main character gets the big window
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

    # Step 1: Position all windows via Wine API
    nn_log ""
    nn_log "Step 1: Positioning windows..."
    WINEPREFIX="${PREFIX}" DISPLAY=:0 wine "${helper}" tile-hwnd "${tile_args[@]}"

    nn_log ""
    nn_log "Tiling complete. ${char_names[main_idx]} is the main window."
}

TEMPLATE="${1:-auto}"
main "$@"
