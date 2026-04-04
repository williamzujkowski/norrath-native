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
WINE_CMD=""

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

detect_wine() {
    if command -v wine64 &>/dev/null; then
        WINE_CMD="wine64"
    elif command -v wine &>/dev/null; then
        WINE_CMD="wine"
    else
        WINE_CMD=""
    fi
}

validate_dependencies() {
    log "Validating dependencies..."
    local missing=()

    detect_wine
    if [[ -z "${WINE_CMD}" ]]; then
        missing+=("wine64/wine")
    fi

    for cmd in vulkaninfo wget tar; do
        if ! command -v "${cmd}" &>/dev/null; then
            missing+=("${cmd}")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log "ERROR: Missing required dependencies: ${missing[*]}"
        log "Install them with: make prereqs"
        log "  Or manually: sudo apt install wine64 vulkan-tools wget tar"
        exit 1
    fi

    log "All dependencies found (wine: ${WINE_CMD})."
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

install_dxvk_dlls() {
    local src_dir="$1"
    local dst_dir="$2"
    local label="$3"

    if [[ ! -d "${src_dir}" ]]; then
        log "WARNING: DXVK source dir ${src_dir} not found, skipping ${label}."
        return 0
    fi

    for dll in "${DXVK_DLLS[@]}"; do
        local src="${src_dir}/${dll}"
        local dst="${dst_dir}/${dll}"

        if [[ ! -f "${src}" ]]; then
            continue
        fi

        if [[ -f "${dst}" ]]; then
            local src_size dst_size
            src_size="$(stat -c '%s' "${src}")"
            dst_size="$(stat -c '%s' "${dst}")"
            if [[ "${src_size}" -eq "${dst_size}" ]]; then
                log "${dll} already in ${label}, skipping."
                continue
            fi
        fi

        log "Installing ${dll} to ${label}..."
        cp "${src}" "${dst}"
    done
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
    # shellcheck disable=SC2064
    trap "rm -rf '${tmpdir}'" RETURN

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

    # Install x64 DLLs to system32 and x32 DLLs to syswow64
    # Both are needed: EQ game is 64-bit, but LaunchPad.exe/CEF is 32-bit
    install_dxvk_dlls "${dxvk_dir}/x64" "${PREFIX}/drive_c/windows/system32" "system32 (x64)"
    install_dxvk_dlls "${dxvk_dir}/x32" "${PREFIX}/drive_c/windows/syswow64" "syswow64 (x32)"

    log "DXVK DLLs installed (x64 + x32)."
}

configure_dxvk_overrides() {
    log "Configuring DXVK DLL overrides..."

    for dll in "${DXVK_OVERRIDE_DLLS[@]}"; do
        run env WINEPREFIX="${PREFIX}" ${WINE_CMD} reg add \
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
    run env WINEPREFIX="${PREFIX}" ${WINE_CMD} reg add "${desktop_key}" \
        /v Default /d "${width}x${height}" /f

    local explorer_key='HKEY_CURRENT_USER\Software\Wine\Explorer'
    run env WINEPREFIX="${PREFIX}" ${WINE_CMD} reg add "${explorer_key}" \
        /v Desktop /d Default /f

    log "Virtual desktop enabled (${RESOLUTION})."
}

install_everquest() {
    local eq_dir="${PREFIX}/drive_c/EverQuest"
    local eq_setup_url="https://launch.daybreakgames.com/installer/EQ_setup.exe"
    local eq_setup="/tmp/EQ_setup.exe"

    if [[ -f "${eq_dir}/LaunchPad.exe" ]]; then
        log "EverQuest already installed at ${eq_dir}, skipping."
        return 0
    fi

    log "Installing EverQuest..."

    if [[ ! -f "${eq_setup}" ]]; then
        log "Downloading EQ installer..."
        run wget -q -O "${eq_setup}" "${eq_setup_url}"
    else
        log "EQ installer already downloaded, reusing."
    fi

    if [[ "${DRY_RUN}" -eq 1 ]]; then
        log "[DRY-RUN] Would run EQ_setup.exe /S /D=C:\\EverQuest"
        return 0
    fi

    log "Running silent install (this may take a moment)..."
    run env WINEPREFIX="${PREFIX}" ${WINE_CMD} "${eq_setup}" /S /D='C:\EverQuest'
    sleep 5

    if [[ -f "${eq_dir}/LaunchPad.exe" ]]; then
        log "EverQuest installed successfully at ${eq_dir}"
    else
        log "WARNING: LaunchPad.exe not found after install. Check manually."
    fi
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
    install_everquest

    log "=== ${SCRIPT_NAME} completed ==="
}

main "$@"
