#!/usr/bin/env bash
set -euo pipefail

# configure_eq.sh — Apply EQ client settings from norrath-native config
#
# Reads norrath-native.yaml for settings and profile, then applies them
# to eqclient.ini. Idempotent — only changes managed keys, preserves
# user settings (keybinds, UI layout, etc.).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0

# Source config reader for defaults and YAML parsing
# shellcheck source=config_reader.sh
source "${SCRIPT_DIR}/config_reader.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Apply EQ client settings from norrath-native.yaml.

Options:
  --prefix PATH   Override WINEPREFIX (default from config: ${NN_PREFIX})
  --profile NAME  Override profile (high|balanced|low|minimal)
  --dry-run       Show what would change without writing
  -h, --help      Show this help

Profiles:
  high      Full quality, single client (default)
  balanced  Good quality for 2-3 clients
  low       Reduced quality for background boxes
  minimal   Stick figures, minimum resources for AFK boxes
EOF
    exit 0
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --prefix)
                if [[ $# -lt 2 ]]; then nn_log "ERROR: --prefix requires a value"; exit 1; fi
                NN_PREFIX="$2"; shift 2 ;;
            --profile)
                if [[ $# -lt 2 ]]; then nn_log "ERROR: --profile requires a value"; exit 1; fi
                NN_PROFILE="$2"; _nn_apply_profile; shift 2 ;;
            --dry-run) DRY_RUN=1; shift ;;
            -h|--help) usage ;;
            *) nn_log "ERROR: Unknown option: $1"; exit 1 ;;
        esac
    done
}

# Apply settings from the TypeScript CLI (source of truth) to the INI file.
# The CLI outputs key=value lines via config:settings:ini.
# This function reads those lines and applies each to the [Defaults] section.
apply_ts_settings() {
    local ini_file="$1"
    local section="${2:-Defaults}"
    local updated=0

    while IFS='=' read -r key value; do
        [[ -z "${key}" ]] && continue
        if grep -q "^${key}=" "${ini_file}" 2>/dev/null; then
            local current
            current="$(grep "^${key}=" "${ini_file}" | head -1 | cut -d= -f2-)"
            if [[ "${current}" != "${value}" ]]; then
                if [[ "${DRY_RUN}" -eq 1 ]]; then
                    nn_log "  [DRY-RUN] Would update: ${key}=${value} (was: ${current})"
                else
                    sed -i "s/^${key}=.*/${key}=${value}/" "${ini_file}"
                    nn_log "  Updated: ${key}=${value} (was: ${current})"
                fi
                updated=$((updated + 1))
            fi
        else
            if [[ "${DRY_RUN}" -eq 1 ]]; then
                nn_log "  [DRY-RUN] Would add: ${key}=${value}"
            else
                if grep -q "^\[${section}\]" "${ini_file}" 2>/dev/null; then
                    sed -i "/^\[${section}\]/a ${key}=${value}" "${ini_file}"
                else
                    echo "${key}=${value}" >> "${ini_file}"
                fi
                nn_log "  Added: ${key}=${value}"
            fi
            updated=$((updated + 1))
        fi
    done < <(cli_cmd config:settings:ini)

    return ${updated}
}

main() {
    parse_args "$@"

    local eq_dir="${NN_PREFIX}/drive_c/EverQuest"
    local ini_file="${eq_dir}/eqclient.ini"

    if [[ ! -d "${eq_dir}" ]]; then
        nn_log "ERROR: EverQuest directory not found at ${eq_dir}"
        nn_log "Run 'make deploy' first."
        exit 1
    fi

    if [[ "${DRY_RUN}" -eq 0 ]]; then
        nn_require_eq_stopped --warn
    fi

    nn_log "Applying settings (profile: ${NN_PROFILE}) to ${ini_file}"

    if [[ ! -f "${ini_file}" ]]; then
        if [[ "${DRY_RUN}" -eq 1 ]]; then
            nn_log "[DRY-RUN] Would create ${ini_file}"
        else
            nn_log "Creating ${ini_file}..."
            echo "[Defaults]" > "${ini_file}"
        fi
    fi

    local total=0

    nn_log "Managed settings ([Defaults] section):"
    apply_ts_settings "${ini_file}" "Defaults" || total=$((total + $?))

    if [[ "${total}" -eq 0 ]]; then
        nn_log "All settings already correct (no changes needed)."
    else
        nn_log "Applied ${total} change(s)."
    fi
}

main "$@"
