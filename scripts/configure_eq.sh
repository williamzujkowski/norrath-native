#!/usr/bin/env bash
set -euo pipefail

# configure_eq.sh — Apply optimized eqclient.ini settings for Linux multiboxing
# Uses the TypeScript config-injector for idempotent INI management.
# Can also be run standalone without Node.js using pure bash fallback.

PREFIX="${HOME}/.wine-eq"
DRY_RUN=0

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Apply optimized eqclient.ini settings for Linux multiboxing.

Options:
  --prefix PATH   WINEPREFIX path (default: ~/.wine-eq)
  --dry-run       Show what would change without writing
  --help          Show this help
EOF
    exit 0
}

log() {
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    printf '[%s] %s\n' "${timestamp}" "$*"
}

# Managed settings — must match src/types/interfaces.ts MANAGED_INI_SETTINGS
declare -A MANAGED_SETTINGS=(
    [WindowedMode]="TRUE"
    [UpdateInBackground]="1"
    [MaxBGFPS]="30"
    [ClientCore0]="-1"
    [ClientCore1]="-1"
    [ClientCore2]="-1"
    [ClientCore3]="-1"
    [ClientCore4]="-1"
    [ClientCore5]="-1"
    [ClientCore6]="-1"
    [ClientCore7]="-1"
    [ClientCore8]="-1"
    [ClientCore9]="-1"
    [ClientCore10]="-1"
    [ClientCore11]="-1"
)

apply_ini_settings() {
    local ini_file="$1"
    local ini_dir
    ini_dir="$(dirname "${ini_file}")"

    if [[ "${DRY_RUN}" -eq 1 ]]; then
        log "[DRY-RUN] Would configure ${ini_file}"
        for key in "${!MANAGED_SETTINGS[@]}"; do
            log "  ${key}=${MANAGED_SETTINGS[${key}]}"
        done
        return 0
    fi

    mkdir -p "${ini_dir}"

    # If file doesn't exist, create with managed settings
    if [[ ! -f "${ini_file}" ]]; then
        log "Creating ${ini_file} with managed settings..."
        {
            echo "[Defaults]"
            for key in $(printf '%s\n' "${!MANAGED_SETTINGS[@]}" | sort); do
                echo "${key}=${MANAGED_SETTINGS[${key}]}"
            done
        } > "${ini_file}"
        log "Created with ${#MANAGED_SETTINGS[@]} managed keys."
        return 0
    fi

    # File exists — update managed keys, preserve user settings
    log "Updating managed settings in ${ini_file}..."
    local tmpfile="${ini_file}.tmp"
    local updated=0

    # Copy existing file, updating managed keys in place
    cp "${ini_file}" "${tmpfile}"

    for key in "${!MANAGED_SETTINGS[@]}"; do
        local value="${MANAGED_SETTINGS[${key}]}"
        if grep -q "^${key}=" "${tmpfile}" 2>/dev/null; then
            # Key exists — update its value
            local current
            current="$(grep "^${key}=" "${tmpfile}" | head -1 | cut -d= -f2-)"
            if [[ "${current}" != "${value}" ]]; then
                sed -i "s/^${key}=.*/${key}=${value}/" "${tmpfile}"
                log "  Updated: ${key}=${value} (was: ${current})"
                updated=$((updated + 1))
            fi
        else
            # Key doesn't exist — append it
            echo "${key}=${value}" >> "${tmpfile}"
            log "  Added: ${key}=${value}"
            updated=$((updated + 1))
        fi
    done

    mv "${tmpfile}" "${ini_file}"

    if [[ "${updated}" -eq 0 ]]; then
        log "All managed settings already correct (no changes)."
    else
        log "Updated ${updated} setting(s)."
    fi
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --prefix)
                if [[ $# -lt 2 ]]; then
                    log "ERROR: --prefix requires a value"; exit 1
                fi
                PREFIX="$2"; shift 2 ;;
            --dry-run) DRY_RUN=1; shift ;;
            --help) usage ;;
            *) log "ERROR: Unknown option: $1"; exit 1 ;;
        esac
    done

    local eq_dir="${PREFIX}/drive_c/EverQuest"
    local ini_file="${eq_dir}/eqclient.ini"

    if [[ ! -d "${eq_dir}" ]]; then
        log "ERROR: EverQuest directory not found at ${eq_dir}"
        log "Run 'make deploy' first to install EverQuest."
        exit 1
    fi

    apply_ini_settings "${ini_file}"
}

main "$@"
