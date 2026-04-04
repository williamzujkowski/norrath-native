#!/usr/bin/env bash
set -euo pipefail

# layout_profiles.sh — Save, load, and switch EQ UI layout profiles
#
# EQ stores window positions per-resolution in UI_charname_server.ini.
# This tool snapshots and restores those positions as named profiles,
# along with viewport settings and chat window routing.
#
# Profiles are stored in ~/.local/share/norrath-native/profiles/
#
# Commands:
#   save NAME      Snapshot current layout as a named profile
#   load NAME      Restore a profile to all characters
#   list           Show available profiles
#   delete NAME    Delete a profile

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config_reader.sh
source "${SCRIPT_DIR}/config_reader.sh"

PREFIX="${NN_PREFIX}"
PROFILES_DIR="${HOME}/.local/share/norrath-native/profiles"

usage() {
    cat <<EOF
Usage: $(basename "$0") <command> [NAME]

Manage EQ UI layout profiles. Save your window arrangement, chat routing,
and viewport settings as named profiles you can switch between.

Commands:
  save NAME        Save current UI layout as a named profile
  load NAME        Load a profile to all characters
  list             Show available profiles
  delete NAME      Delete a profile
  -h, --help       Show this help

Built-in profiles:
  ultrawide-solo   Optimized for 21:9 single client (centered viewport)
  ultrawide-multi  Optimized for 21:9 multibox (compact windows)
  standard-solo    Standard 16:9 single client
  standard-multi   Standard 16:9 multibox (2x2 grid friendly)

Examples:
  $(basename "$0") save my-raid-layout
  $(basename "$0") load ultrawide-solo
  $(basename "$0") list
EOF
    exit 0
}

log() {
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    printf '[%s] %s\n' "${timestamp}" "$*"
}

ensure_profiles_dir() {
    mkdir -p "${PROFILES_DIR}"
}

# Save the current UI layout as a named profile
cmd_save() {
    local name="${1:-}"
    if [[ -z "${name}" ]]; then
        log "ERROR: Profile name required. Usage: $(basename "$0") save NAME"
        exit 1
    fi

    ensure_profiles_dir
    local profile_dir="${PROFILES_DIR}/${name}"
    mkdir -p "${profile_dir}"

    local eq_dir="${PREFIX}/drive_c/EverQuest"
    local count=0

    # Save UI INI files (contain window positions + chat routing)
    for ui_file in "${eq_dir}"/UI_*_*.ini; do
        [[ -f "${ui_file}" ]] || continue
        cp "${ui_file}" "${profile_dir}/"
        count=$((count + 1))
    done

    # Save eqclient.ini VideoMode + TextColors sections
    if [[ -f "${eq_dir}/eqclient.ini" ]]; then
        cp "${eq_dir}/eqclient.ini" "${profile_dir}/eqclient.ini"
        count=$((count + 1))
    fi

    # Save viewport info
    local monitor_res
    monitor_res="$(DISPLAY=:0 xrandr 2>/dev/null | grep ' connected primary' | grep -oP '\d+x\d+' | head -1 || echo 'unknown')"
    local wine_res
    wine_res="$(grep '"Default"=' "${PREFIX}/user.reg" 2>/dev/null | grep -oP '\d+x\d+' | head -1 || echo 'unknown')"

    cat > "${profile_dir}/profile.json" << PEOF
{
  "name": "${name}",
  "saved_at": "$(date -Iseconds)",
  "monitor_resolution": "${monitor_res}",
  "wine_resolution": "${wine_res}",
  "files": ${count}
}
PEOF

    log "Profile '${name}' saved (${count} files) to ${profile_dir}"
    log "  Monitor: ${monitor_res}, Wine: ${wine_res}"
}

# Load a profile, applying to all characters
cmd_load() {
    local name="${1:-}"
    if [[ -z "${name}" ]]; then
        log "ERROR: Profile name required. Usage: $(basename "$0") load NAME"
        exit 1
    fi

    # Check built-in profiles first
    if [[ -f "${SCRIPT_DIR}/profiles/${name}.sh" ]]; then
        log "Loading built-in profile: ${name}"
        # shellcheck disable=SC1090
        source "${SCRIPT_DIR}/profiles/${name}.sh"
        return 0
    fi

    local profile_dir="${PROFILES_DIR}/${name}"
    if [[ ! -d "${profile_dir}" ]]; then
        log "ERROR: Profile '${name}' not found."
        log "Available profiles:"
        cmd_list
        exit 1
    fi

    local eq_dir="${PREFIX}/drive_c/EverQuest"

    # Warn if EQ is running
    if WINEPREFIX="${PREFIX}" wineserver -k0 2>/dev/null; then
        log "WARNING: EQ is running. Camp all characters first."
        log "  Layout changes will be overwritten when you zone/camp."
    fi

    local count=0

    # Restore UI INI files
    for saved_file in "${profile_dir}"/UI_*_*.ini; do
        [[ -f "${saved_file}" ]] || continue
        local basename
        basename="$(basename "${saved_file}")"
        if [[ -f "${eq_dir}/${basename}" ]]; then
            cp "${saved_file}" "${eq_dir}/${basename}"
            log "  Restored: ${basename}"
            count=$((count + 1))
        else
            log "  Skipped: ${basename} (character not found in current prefix)"
        fi
    done

    # Restore eqclient.ini VideoMode section only (preserve other settings)
    if [[ -f "${profile_dir}/eqclient.ini" ]] && [[ -f "${eq_dir}/eqclient.ini" ]]; then
        # Extract VideoMode values from saved profile
        local saved_width saved_height
        saved_width="$(grep "^Width=" "${profile_dir}/eqclient.ini" | head -1 | cut -d= -f2)"
        saved_height="$(grep "^Height=" "${profile_dir}/eqclient.ini" | head -1 | cut -d= -f2)"
        if [[ -n "${saved_width}" ]] && [[ -n "${saved_height}" ]]; then
            sed -i "s/^Width=.*/Width=${saved_width}/" "${eq_dir}/eqclient.ini"
            sed -i "s/^Height=.*/Height=${saved_height}/" "${eq_dir}/eqclient.ini"
            sed -i "s/^WindowedWidth=.*/WindowedWidth=${saved_width}/" "${eq_dir}/eqclient.ini"
            sed -i "s/^WindowedHeight=.*/WindowedHeight=${saved_height}/" "${eq_dir}/eqclient.ini"
            log "  Restored VideoMode: ${saved_width}x${saved_height}"
        fi
        count=$((count + 1))
    fi

    # Show profile metadata
    if [[ -f "${profile_dir}/profile.json" ]]; then
        local saved_at monitor
        saved_at="$(grep '"saved_at"' "${profile_dir}/profile.json" | grep -oP '"\d{4}-[^"]+' | tr -d '"' || echo 'unknown')"
        monitor="$(grep '"monitor_resolution"' "${profile_dir}/profile.json" | grep -oP '\d+x\d+' || echo 'unknown')"
        log "  Saved: ${saved_at}, Monitor: ${monitor}"
    fi

    log "Profile '${name}' loaded (${count} files)."
    log "In-game: /loadskin Default 1  (the 1 preserves window positions)"
}

# List available profiles
cmd_list() {
    ensure_profiles_dir

    # Built-in profiles
    log "Built-in profiles:"
    log "  ultrawide-solo    21:9 single client, centered viewport with sidebars"
    log "  ultrawide-multi   21:9 multibox, compact windows"
    log "  standard-solo     16:9 single client, full screen"
    log "  standard-multi    16:9 multibox, 2x2 grid friendly"
    log ""

    # User-saved profiles
    local count=0
    if [[ -d "${PROFILES_DIR}" ]]; then
        for profile_dir in "${PROFILES_DIR}"/*/; do
            [[ -d "${profile_dir}" ]] || continue
            local name
            name="$(basename "${profile_dir}")"
            local info=""
            if [[ -f "${profile_dir}/profile.json" ]]; then
                local monitor
                monitor="$(grep '"monitor_resolution"' "${profile_dir}/profile.json" | grep -oP '\d+x\d+' || echo '?')"
                local saved
                saved="$(grep '"saved_at"' "${profile_dir}/profile.json" | grep -oP '\d{4}-\d{2}-\d{2}' || echo '?')"
                info=" (${monitor}, saved ${saved})"
            fi
            log "  ${name}${info}"
            count=$((count + 1))
        done
    fi

    if [[ "${count}" -eq 0 ]]; then
        log "User profiles:"
        log "  (none — save one with: $(basename "$0") save NAME)"
    else
        log "  ${count} user profile(s) total"
    fi
}

# Delete a profile
cmd_delete() {
    local name="${1:-}"
    if [[ -z "${name}" ]]; then
        log "ERROR: Profile name required."
        exit 1
    fi

    local profile_dir="${PROFILES_DIR}/${name}"
    if [[ ! -d "${profile_dir}" ]]; then
        log "ERROR: Profile '${name}' not found."
        exit 1
    fi

    rm -rf "${profile_dir}"
    log "Profile '${name}' deleted."
}

# Main dispatch
case "${1:-help}" in
    save)   cmd_save "${2:-}" ;;
    load)   cmd_load "${2:-}" ;;
    list)   cmd_list ;;
    delete) cmd_delete "${2:-}" ;;
    -h|--help) usage ;;
    *)
        log "Unknown command: ${1:-}"
        usage
        ;;
esac
