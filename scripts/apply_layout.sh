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

# Layout application delegated to TypeScript (src/config-injector.ts).
# cli_cmd layout:apply writes directly to the INI file.
apply_layout() {
    local ui_file="$1"
    local result
    result="$(cli_cmd layout:apply "${ui_file}" 2>/dev/null)"
    local changed
    changed="$(echo "${result}" | grep -oP '"changed": \K\d+' || echo '0')"
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
