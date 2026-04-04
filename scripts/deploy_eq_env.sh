#!/usr/bin/env bash
set -euo pipefail

# deploy_eq_env.sh — Provision a Wine prefix with DXVK for EverQuest
# Usage: deploy_eq_env.sh [--dry-run] [--prefix PATH] [--resolution WxH]

readonly SCRIPT_NAME="deploy_eq_env.sh"
readonly LOG_DIR="${HOME}/.local/share/norrath-native"
readonly LOG_FILE="${LOG_DIR}/deploy.log"
readonly DXVK_API_URL="https://api.github.com/repos/doitsujin/dxvk/releases/latest"
readonly DXVK_DLLS=("d3d11.dll" "dxgi.dll" "d3d10core.dll" "d3d9.dll")
readonly DXVK_OVERRIDE_DLLS=("d3d11" "dxgi")

DRY_RUN=0
PREFIX="${HOME}/.wine-eq"
RESOLUTION="1920x1080"

usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

Provision a Wine prefix with DXVK for running EverQuest under Wine.

Options:
  --dry-run           Print every action without touching the filesystem
  --prefix PATH       Set WINEPREFIX (default: ~/.wine-eq)
  --resolution WxH    Virtual desktop resolution (default: 1920x1080)
  --help              Show this help message

Examples:
  ${SCRIPT_NAME}
  ${SCRIPT_NAME} --dry-run
  ${SCRIPT_NAME} --prefix ~/my-wine --resolution 2560x1440
EOF
    exit 0
}

log() {
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    printf '[%s] %s\n' "${timestamp}" "$*" | tee -a "${LOG_FILE}"
}

run() {
    if [[ "${DRY_RUN}" -eq 1 ]]; then
        log "[DRY-RUN] $*"
    else
        log "[RUN] $*"
        "$@"
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=1
                shift
                ;;
            --prefix)
                PREFIX="$2"
                shift 2
                ;;
            --resolution)
                RESOLUTION="$2"
                shift 2
                ;;
            --help)
                usage
                ;;
            *)
                log "ERROR: Unknown option: $1"
                usage
                ;;
        esac
    done
}

ensure_log_dir() {
    if [[ ! -d "${LOG_DIR}" ]]; then
        mkdir -p "${LOG_DIR}"
    fi
}

validate_dependencies() {
    log "Validating dependencies..."
    local missing=()

    for cmd in wine64 vulkaninfo wget tar; do
        if ! command -v "${cmd}" &>/dev/null; then
            missing+=("${cmd}")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log "ERROR: Missing required dependencies: ${missing[*]}"
        log "Install them with:"
        log "  sudo apt install wine64 vulkan-tools wget tar    # Debian/Ubuntu"
        log "  sudo dnf install wine vulkan-tools wget tar      # Fedora"
        log "  sudo pacman -S wine vulkan-tools wget tar        # Arch"
        exit 1
    fi

    log "All dependencies found."
}

create_wineprefix() {
    log "Setting up WINEPREFIX at ${PREFIX}..."

    if [[ -d "${PREFIX}" ]]; then
        log "Prefix already exists, skipping init."
        return 0
    fi

    run env WINEPREFIX="${PREFIX}" WINEARCH=win64 wineboot --init
    log "WINEPREFIX created."
}

download_and_install_dxvk() {
    log "Downloading latest DXVK release..."

    local tarball_url
    tarball_url="$(wget -qO- "${DXVK_API_URL}" \
        | grep -oP '"browser_download_url"\s*:\s*"\K[^"]+\.tar\.gz' \
        | head -n 1)"

    if [[ -z "${tarball_url}" ]]; then
        log "ERROR: Could not determine DXVK download URL from GitHub API."
        exit 1
    fi

    log "DXVK tarball URL: ${tarball_url}"

    local tmpdir
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "${tmpdir}"' RETURN

    local tarball="${tmpdir}/dxvk.tar.gz"
    run wget -q -O "${tarball}" "${tarball_url}"

    if [[ "${DRY_RUN}" -eq 1 ]]; then
        log "[DRY-RUN] Would extract ${tarball} to ${tmpdir}"
        log "[DRY-RUN] Would copy DXVK DLLs to ${PREFIX}/drive_c/windows/system32/"
        return 0
    fi

    tar -xzf "${tarball}" -C "${tmpdir}"

    local dxvk_dir
    dxvk_dir="$(find "${tmpdir}" -maxdepth 1 -type d -name 'dxvk-*' | head -n 1)"
    if [[ -z "${dxvk_dir}" ]]; then
        log "ERROR: Could not find extracted DXVK directory."
        exit 1
    fi

    local sys32="${PREFIX}/drive_c/windows/system32"
    local src_dir="${dxvk_dir}/x64"

    for dll in "${DXVK_DLLS[@]}"; do
        local src="${src_dir}/${dll}"
        local dst="${sys32}/${dll}"

        if [[ ! -f "${src}" ]]; then
            log "WARNING: ${dll} not found in DXVK release, skipping."
            continue
        fi

        if [[ -f "${dst}" ]]; then
            local src_size dst_size
            src_size="$(stat -c '%s' "${src}")"
            dst_size="$(stat -c '%s' "${dst}")"
            if [[ "${src_size}" -eq "${dst_size}" ]]; then
                log "${dll} already installed with matching size, skipping."
                continue
            fi
        fi

        log "Installing ${dll} to system32..."
        cp "${src}" "${dst}"
    done

    log "DXVK DLLs installed."
}

configure_dxvk_overrides() {
    log "Configuring DXVK DLL overrides..."

    for dll in "${DXVK_OVERRIDE_DLLS[@]}"; do
        run env WINEPREFIX="${PREFIX}" wine64 reg add \
            'HKEY_CURRENT_USER\Software\Wine\DllOverrides' \
            /v "${dll}" /d native /f
    done

    log "DLL overrides configured."
}

enable_virtual_desktop() {
    log "Enabling virtual desktop at ${RESOLUTION}..."

    local width height
    width="${RESOLUTION%%x*}"
    height="${RESOLUTION##*x}"

    local desktop_key='HKEY_CURRENT_USER\Software\Wine\Explorer\Desktops'
    run env WINEPREFIX="${PREFIX}" wine64 reg add "${desktop_key}" \
        /v Default /d "${width}x${height}" /f

    local explorer_key='HKEY_CURRENT_USER\Software\Wine\Explorer'
    run env WINEPREFIX="${PREFIX}" wine64 reg add "${explorer_key}" \
        /v Desktop /d Default /f

    log "Virtual desktop enabled (${RESOLUTION})."
}

main() {
    parse_args "$@"
    ensure_log_dir
    log "=== ${SCRIPT_NAME} started ==="
    log "Dry-run: ${DRY_RUN}, Prefix: ${PREFIX}, Resolution: ${RESOLUTION}"

    validate_dependencies
    create_wineprefix
    download_and_install_dxvk
    configure_dxvk_overrides
    enable_virtual_desktop

    log "=== ${SCRIPT_NAME} completed ==="
}

main "$@"
