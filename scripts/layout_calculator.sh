#!/usr/bin/env bash
set -euo pipefail

# layout_calculator.sh — Calculate and apply layouts from templates
#
# Reads percentage-based layout templates and calculates pixel positions
# for the current screen resolution. Applies both Wine window tiling
# and EQ internal UI positioning.
#
# Commands:
#   apply TEMPLATE   Calculate and apply a layout template
#   show  TEMPLATE   Preview calculated positions without applying
#   list             Show available templates

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config_reader.sh
source "${SCRIPT_DIR}/config_reader.sh"

PREFIX="${NN_PREFIX}"
LAYOUTS_DIR="${SCRIPT_DIR}/../layouts"
DRY_RUN=0

usage() {
    cat <<EOF
Usage: $(basename "$0") <command> [TEMPLATE] [OPTIONS]

Calculate and apply UI layout templates.

Commands:
  apply TEMPLATE    Apply a layout template
  show TEMPLATE     Preview calculated pixel positions
  list              Show available templates

Options:
  --prefix PATH     Override WINEPREFIX
  --dry-run         Preview without writing
  --force           Apply even if EQ is running (changes may be lost)
  --character NAME  Apply only to specific character (e.g., Rootkit_povar)
  --role main|box   Override role assignment for --character
  -h, --help        Show this help

Templates are in layouts/ directory. Copy and customize for your own.

Examples:
  $(basename "$0") list
  $(basename "$0") show multibox-bard-pull
  $(basename "$0") apply multibox-bard-pull
  $(basename "$0") apply raid-solo --character Rootkit_povar --role main
EOF
    exit 0
}

# Calculate pixel value from percentage and total
calc() {
    local pct="$1" total="$2"
    echo $(( pct * total / 100 ))
}

# Get Wine desktop resolution
get_desktop_size() {
    local res="${NN_RESOLUTION}"
    local w="${res%%x*}"
    local h="${res##*x}"
    printf '%s %s' "${w}" "${h}"
}

# Apply Wine window tiling from template
apply_tiling() {
    # $1 = template file path (template vars already sourced into env)
    local desktop_w desktop_h
    read -r desktop_w desktop_h <<< "$(get_desktop_size)"

    nn_log "Wine desktop: ${desktop_w}x${desktop_h}"

    # Find EQ game windows (exact title match, excludes Discord etc.)
    local -a real_windows=()
    while IFS= read -r wid; do
        real_windows+=("${wid}")
    done < <(nn_find_eq_windows | head -6)

    # Detect XWayland coordinate scaling (positions doubled on some compositors)
    local xw_scale=1
    if [[ ${#real_windows[@]} -gt 0 ]]; then
        DISPLAY=:0 xdotool windowmove "${real_windows[0]}" 100 100 2>/dev/null || true
        local reported_x
        reported_x="$(DISPLAY=:0 xdotool getwindowgeometry "${real_windows[0]}" 2>/dev/null | grep 'Position' | grep -oP '\d+' | head -1 || echo '100')"
        if [[ "${reported_x}" -eq 200 ]]; then
            xw_scale=2
            nn_log "  XWayland coordinate doubling detected (compensating)."
        fi
    fi

    local i=1
    while true; do
        local var_x="TILE_${i}_X" var_y="TILE_${i}_Y" var_w="TILE_${i}_W" var_h="TILE_${i}_H"
        local tx="${!var_x:-}" ty="${!var_y:-}" tw="${!var_w:-}" th="${!var_h:-}"
        [[ -z "${tx}" ]] && break

        local px py pw ph
        px="$(calc "${tx}" "${desktop_w}")"
        py="$(calc "${ty}" "${desktop_h}")"
        pw="$(calc "${tw}" "${desktop_w}")"
        ph="$(calc "${th}" "${desktop_h}")"

        # Compensate for XWayland position doubling
        local move_x=$((px / xw_scale))
        local move_y=$((py / xw_scale))

        local idx=$((i - 1))
        if [[ "${idx}" -lt "${#real_windows[@]}" ]]; then
            if [[ "${DRY_RUN}" -eq 0 ]]; then
                local helper="${SCRIPT_DIR}/../helpers/wine_resize.exe"
                if [[ -f "${helper}" ]]; then
                    # Use Wine's SetWindowPos API (triggers proper WM_SIZE for re-render)
                    WINEPREFIX="${PREFIX}" DISPLAY=:0 wine "${helper}" "${idx}" "${px}" "${py}" "${pw}" "${ph}" 2>/dev/null || true
                else
                    # Fallback to xdotool (positions but doesn't trigger re-render)
                    DISPLAY=:0 xdotool windowmove "${real_windows[${idx}]}" "${move_x}" "${move_y}" 2>/dev/null || true
                    DISPLAY=:0 xdotool windowsize "${real_windows[${idx}]}" "${pw}" "${ph}" 2>/dev/null || true
                fi
            fi
            nn_log "  Window ${i}: ${px},${py} ${pw}x${ph}"
        else
            nn_log "  Window ${i}: ${px},${py} ${pw}x${ph} (no window to tile)"
        fi
        i=$((i + 1))
    done
}

# Apply EQ internal UI positions to a character's INI
apply_ui_positions() {
    local _template_file="$1"  # reserved for future template-specific logic
    local ui_file="$2"
    local role="${3:-main}"  # main or box

    local basename
    basename="$(basename "${ui_file}")"

    # Get the resolution tag EQ uses (e.g., 1920x1054)
    local res_tag
    res_tag="$(grep -oP '\d+x\d+' "${ui_file}" 2>/dev/null | head -1)"
    if [[ -z "${res_tag}" ]]; then
        nn_log "  ${basename}: no resolution tag found, skipping UI positions"
        return 0
    fi
    local tag_w="${res_tag%%x*}"
    local tag_h="${res_tag##*x}"

    nn_log "  ${basename} (${role}, ${res_tag}):"

    # Map template variables to EQ UI sections
    local prefix_var
    if [[ "${role}" == "main" ]]; then
        prefix_var="MAIN"
    else
        prefix_var="BOX"
    fi

    # Position mappings: TEMPLATE_VAR -> EQ_SECTION
    local -a mappings=(
        "CHAT:MainChat"
        "TARGET:TargetWindow"
        "PLAYER:PlayerWindow"
        "GROUP:GroupWindow"
        "HOTBAR:HotButtonWnd"
        "BUFFS:BuffWindow"
        "EXT_TARGET:ExtendedTargetWnd"
    )

    local changed=0
    for mapping in "${mappings[@]}"; do
        local tmpl_name="${mapping%%:*}"
        local eq_section="${mapping##*:}"

        local var_x="${prefix_var}_${tmpl_name}_X"
        local var_y="${prefix_var}_${tmpl_name}_Y"
        local var_w="${prefix_var}_${tmpl_name}_W"
        local var_h="${prefix_var}_${tmpl_name}_H"

        local tx="${!var_x:-}" ty="${!var_y:-}" tw="${!var_w:-}" th="${!var_h:-}"
        [[ -z "${tx}" ]] && continue

        local px py pw ph
        px="$(calc "${tx}" "${tag_w}")"
        py="$(calc "${ty}" "${tag_h}")"
        pw="$(calc "${tw}" "${tag_w}")"
        ph="$(calc "${th}" "${tag_h}")"

        if [[ "${DRY_RUN}" -eq 0 ]]; then
            # Update or add position entries in the INI
            for key_val in "XPos${res_tag}=${px}" "YPos${res_tag}=${py}" "Width${res_tag}=${pw}" "Height${res_tag}=${ph}" \
                           "RestoreXPos${res_tag}=${px}" "RestoreYPos${res_tag}=${py}" "RestoreWidth${res_tag}=${pw}" "RestoreHeight${res_tag}=${ph}"; do
                local key="${key_val%%=*}"
                local val="${key_val##*=}"

                # Find the section and update/add the key
                if grep -q "^\[${eq_section}\]" "${ui_file}" 2>/dev/null; then
                    if grep -A100 "^\[${eq_section}\]" "${ui_file}" | grep -q "^${key}="; then
                        sed -i "/^\[${eq_section}\]/,/^\[/{s/^${key}=.*/${key}=${val}/}" "${ui_file}"
                    fi
                fi
            done
        fi

        nn_log "    ${eq_section}: ${px},${py} ${pw}x${ph}"
        changed=$((changed + 1))
    done

    return 0
}

cmd_list() {
    nn_log "Available layout templates:"
    nn_log ""
    for conf in "${LAYOUTS_DIR}"/*.conf; do
        [[ -f "${conf}" ]] || continue
        local name
        name="$(basename "${conf}" .conf)"
        # shellcheck disable=SC1090
        source "${conf}"
        printf '  %-25s %s\n' "${name}" "${LAYOUT_DESC:-}"
    done
    nn_log ""
    nn_log "Apply with: $(basename "$0") apply TEMPLATE_NAME"
    nn_log "Preview with: $(basename "$0") show TEMPLATE_NAME"
}

cmd_show() {
    local template="${1:-}"
    if [[ -z "${template}" ]]; then
        nn_log "ERROR: Template name required."
        cmd_list
        exit 1
    fi

    local conf="${LAYOUTS_DIR}/${template}.conf"
    if [[ ! -f "${conf}" ]]; then
        nn_log "ERROR: Template '${template}' not found at ${conf}"
        cmd_list
        exit 1
    fi

    # shellcheck disable=SC1090
    source "${conf}"

    local desktop_w desktop_h
    read -r desktop_w desktop_h <<< "$(get_desktop_size)"

    nn_log "Template: ${LAYOUT_NAME:-${template}}"
    nn_log "Description: ${LAYOUT_DESC:-}"
    nn_log "Instances: ${LAYOUT_INSTANCES:-1}"
    nn_log "Desktop: ${desktop_w}x${desktop_h}"
    nn_log ""
    nn_log "Wine window tiling:"

    local i=1
    while true; do
        local var_x="TILE_${i}_X" var_y="TILE_${i}_Y" var_w="TILE_${i}_W" var_h="TILE_${i}_H"
        local tx="${!var_x:-}" ty="${!var_y:-}" tw="${!var_w:-}" th="${!var_h:-}"
        [[ -z "${tx}" ]] && break

        local px py pw ph
        px="$(calc "${tx}" "${desktop_w}")"
        py="$(calc "${ty}" "${desktop_h}")"
        pw="$(calc "${tw}" "${desktop_w}")"
        ph="$(calc "${th}" "${desktop_h}")"
        nn_log "  Window ${i}: (${tx}%,${ty}%) → ${px},${py} ${pw}x${ph}"
        i=$((i + 1))
    done

    nn_log ""
    nn_log "EQ UI positions (main role, relative to EQ window):"
    for var_name in MAIN_CHAT MAIN_TARGET MAIN_PLAYER MAIN_GROUP MAIN_HOTBAR MAIN_BUFFS; do
        local vx="${var_name}_X" vy="${var_name}_Y" vw="${var_name}_W" vh="${var_name}_H"
        local tx="${!vx:-}" ty="${!vy:-}" tw="${!vw:-}" th="${!vh:-}"
        [[ -z "${tx}" ]] && continue
        local short="${var_name#MAIN_}"
        printf '    %-15s %3s%%,%3s%% → %3s%%x%3s%%\n' "${short}" "${tx}" "${ty}" "${tw}" "${th}"
    done
}

cmd_apply() {
    local template="${1:-}"
    local target_char="" target_role="" FORCE=0

    shift || true
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --character)
                if [[ $# -lt 2 ]]; then nn_log "ERROR: --character requires a value"; exit 1; fi
                target_char="$2"; shift 2 ;;
            --role)
                if [[ $# -lt 2 ]]; then nn_log "ERROR: --role requires main or box"; exit 1; fi
                target_role="$2"; shift 2 ;;
            --prefix)
                if [[ $# -lt 2 ]]; then nn_log "ERROR: --prefix requires a value"; exit 1; fi
                PREFIX="$2"; shift 2 ;;
            --dry-run) DRY_RUN=1; shift ;;
            --force) FORCE=1; shift ;;
            *) shift ;;
        esac
    done

    if [[ -z "${template}" ]]; then
        nn_log "ERROR: Template name required."
        cmd_list
        exit 1
    fi

    local conf="${LAYOUTS_DIR}/${template}.conf"
    if [[ ! -f "${conf}" ]]; then
        nn_log "ERROR: Template '${template}' not found."
        cmd_list
        exit 1
    fi

    # shellcheck disable=SC1090
    source "${conf}"

    nn_log "Applying template: ${LAYOUT_NAME:-${template}}"

    if [[ "${FORCE:-0}" -eq 0 ]] && [[ "${DRY_RUN}" -eq 0 ]]; then
        nn_require_eq_stopped || exit 1
    fi

    # Step 1: Tile Wine windows
    nn_log ""
    nn_log "Step 1: Wine window tiling"
    apply_tiling "${conf}"

    # Step 2: Apply EQ UI positions to character INIs
    nn_log ""
    nn_log "Step 2: EQ internal UI positions"

    local eq_dir="${PREFIX}/drive_c/EverQuest"
    local char_idx=0

    for ui_file in "${eq_dir}"/UI_*_*.ini; do
        [[ -f "${ui_file}" ]] || continue
        local basename
        basename="$(basename "${ui_file}" .ini)"
        local char_name="${basename#UI_}"

        # Skip if targeting a specific character
        if [[ -n "${target_char}" ]] && [[ "${char_name}" != *"${target_char}"* ]]; then
            continue
        fi

        # Determine role: first character is main, rest are box
        local role
        if [[ -n "${target_role}" ]]; then
            role="${target_role}"
        elif [[ "${char_idx}" -eq 0 ]]; then
            role="main"
        else
            role="box"
        fi

        apply_ui_positions "${conf}" "${ui_file}" "${role}"
        char_idx=$((char_idx + 1))
    done

    # Step 3: Viewport
    if [[ "${VIEWPORT_MODE:-none}" == "auto" ]]; then
        nn_log ""
        nn_log "Step 3: Viewport"
        local monitor_w monitor_h
        monitor_w="$(DISPLAY=:0 xrandr 2>/dev/null | grep ' connected primary' | grep -oP '\d+' | head -1 || echo '1920')"
        monitor_h="$(DISPLAY=:0 xrandr 2>/dev/null | grep ' connected primary' | grep -oP '\d+' | head -2 | tail -1 || echo '1080')"

        local ratio
        ratio="$(echo "${monitor_w} ${monitor_h}" | awk '{printf "%.2f", $1/$2}')"

        if awk "BEGIN {exit !(${ratio} > 1.78)}" 2>/dev/null; then
            local vp_w=$(( monitor_h * 16 / 9 ))
            local vp_offset=$(( (monitor_w - vp_w) / 2 ))
            nn_log "  Ultrawide detected. In-game command:"
            nn_log "  /viewport ${vp_offset} 0 ${vp_w} ${monitor_h}"
        else
            nn_log "  16:9 monitor — no viewport adjustment needed."
        fi
    fi

    # Check if resolution needs updating
    local wine_res
    wine_res="$(grep '"Default"=' "${PREFIX}/user.reg" 2>/dev/null | grep -oP '\d+x\d+' | head -1 || echo '')"
    if [[ -n "${wine_res}" ]] && [[ "${wine_res}" != "${NN_RESOLUTION}" ]]; then
        nn_log ""
        nn_log "NOTE: Wine desktop is ${wine_res} but your monitor is ${NN_RESOLUTION}."
        nn_log "  Run: make resolution   (to fill your screen)"
    fi

    nn_log ""
    nn_log "UI positions written to INI files."
    nn_log ""
    nn_log "Next steps:"
    nn_log "  1. make launch-multi        (start EQ instances)"
    nn_log "  2. Wait for all windows to load"
    nn_log "  3. make tile                (arrange windows on screen)"
    nn_log "  4. In-game: /loadskin Default 1"
}

# Main dispatch
case "${1:-help}" in
    apply)  cmd_apply "${2:-}" "${@:3}" ;;
    show)   cmd_show "${2:-}" ;;
    list)   cmd_list ;;
    -h|--help) usage ;;
    *)
        nn_log "Unknown command: ${1:-}"
        usage
        ;;
esac
