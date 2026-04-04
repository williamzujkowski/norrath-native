#!/usr/bin/env bash
set -euo pipefail

# apply_layout.sh — Apply recommended 4-window chat layout
#
# Modifies the UI_charname_server.ini ChatManager section to route
# chat channels into organized windows:
#   0 = Social (tells, guild, group, raid)
#   1 = Combat (your damage, heals, incoming)
#   2 = Spam   (others' combat, NPC, system)
#   3 = Alerts (death, loot, XP, tasks)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config_reader.sh
source "${SCRIPT_DIR}/config_reader.sh"

DRY_RUN=0
FORCE=0
PREFIX="${NN_PREFIX}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Apply the recommended 4-window chat layout to EverQuest.

Windows:
  0 "Social"  — Tells, guild, group, raid, say, emote, OOC
  1 "Combat"  — Your damage, heals, incoming, crits, pet
  2 "Spam"    — Others' combat, NPC, system (dimmed)
  3 "Alerts"  — Death, loot, XP, tasks, achievements

Options:
  --prefix PATH   Override WINEPREFIX
  --dry-run       Preview changes without writing
  --force         Apply even if EQ is running (changes may be lost)
  -h, --help      Show this help

See docs/chat-layout.md for the full design rationale.
EOF
    exit 0
}

# Channel routing map: filter_id -> window_index, sourced from TypeScript (canonical data).
# 0=Social, 1=Combat, 2=Spam, 3=Alerts
build_channel_map() {
    cli_cmd layout:data
}

apply_layout() {
    local ui_file="$1"
    local changed=0

    # Update ChatManager NumWindows
    if grep -q "^NumWindows=" "${ui_file}"; then
        local current
        current="$(grep "^NumWindows=" "${ui_file}" | head -1 | cut -d= -f2)"
        if [[ "${current}" != "4" ]]; then
            if [[ "${DRY_RUN}" -eq 0 ]]; then
                sed -i "s/^NumWindows=.*/NumWindows=4/" "${ui_file}"
            fi
            nn_log "  NumWindows: ${current} → 4"
            changed=$((changed + 1))
        fi
    fi

    # Update window names
    local -a names=("Social" "Combat" "Spam" "Alerts & Loot")
    for i in 0 1 2 3; do
        local key="ChatWindow${i}_Name"
        local val="${names[${i}]}"
        if grep -q "^${key}=" "${ui_file}"; then
            if [[ "${DRY_RUN}" -eq 0 ]]; then
                sed -i "s/^${key}=.*/${key}=${val}/" "${ui_file}"
            fi
        else
            if [[ "${DRY_RUN}" -eq 0 ]]; then
                sed -i "/\[ChatManager\]/a ${key}=${val}" "${ui_file}"
            fi
        fi
    done

    # Update ChannelMap entries
    while read -r filter_id window_id; do
        local key="ChannelMap${filter_id}"
        if grep -q "^${key}=" "${ui_file}"; then
            local current
            current="$(grep "^${key}=" "${ui_file}" | head -1 | cut -d= -f2)"
            if [[ "${current}" != "${window_id}" ]]; then
                if [[ "${DRY_RUN}" -eq 0 ]]; then
                    sed -i "s/^${key}=.*/${key}=${window_id}/" "${ui_file}"
                fi
                changed=$((changed + 1))
            fi
        else
            if [[ "${DRY_RUN}" -eq 0 ]]; then
                sed -i "/\[ChatManager\]/a ${key}=${window_id}" "${ui_file}"
            fi
            changed=$((changed + 1))
        fi
    done < <(build_channel_map)

    printf '%d' "${changed}"
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --prefix)
                if [[ $# -lt 2 ]]; then nn_log "ERROR: --prefix requires a value"; exit 1; fi
                PREFIX="$2"; shift 2 ;;
            --dry-run) DRY_RUN=1; shift ;;
            --force) FORCE=1; shift ;;
            -h|--help) usage ;;
            *) nn_log "ERROR: Unknown option: $1"; exit 1 ;;
        esac
    done

    local eq_dir="${PREFIX}/drive_c/EverQuest"

    if [[ "${FORCE}" -eq 0 ]]; then
        nn_require_eq_stopped || exit 1
    fi

    # Find all UI INI files (one per character)
    local -a ui_files=()
    while IFS= read -r -d '' f; do
        ui_files+=("${f}")
    done < <(find "${eq_dir}" -maxdepth 1 -name "UI_*_*.ini" -print0 2>/dev/null)

    if [[ ${#ui_files[@]} -eq 0 ]]; then
        nn_log "ERROR: No UI_charname_server.ini files found in ${eq_dir}"
        nn_log "Log in to a character first to generate UI files."
        exit 1
    fi

    for ui_file in "${ui_files[@]}"; do
        local basename
        basename="$(basename "${ui_file}")"
        nn_log "Applying 4-window layout to ${basename}..."

        if [[ "${DRY_RUN}" -eq 1 ]]; then
            nn_log "  [DRY-RUN] Would set: 4 windows (Social, Combat, Spam, Alerts)"
            local count
            count="$(apply_layout "${ui_file}")"
            nn_log "  Would change ${count} channel routings."
        else
            local count
            count="$(apply_layout "${ui_file}")"
            nn_log "  Updated ${count} channel routings."
        fi
    done

    nn_log ""
    nn_log "Layout applied. In-game: /loadskin to reload UI."
    nn_log "See docs/chat-layout.md for window descriptions."
}

main "$@"
