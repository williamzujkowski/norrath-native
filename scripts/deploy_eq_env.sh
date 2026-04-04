#!/usr/bin/env bash
set -euo pipefail

# deploy_eq_env.sh — Provision a Wine prefix with DXVK for EverQuest
# Usage: deploy_eq_env.sh [--dry-run] [--prefix PATH] [--resolution WxH]

readonly SCRIPT_NAME="deploy_eq_env.sh"
readonly LOG_DIR="${HOME}/.local/share/norrath-native"
readonly DXVK_API_URL="https://api.github.com/repos/doitsujin/dxvk/releases/latest"
readonly DXVK_DLLS=("d3d11.dll" "dxgi.dll" "d3d10core.dll" "d3d9.dll")
readonly DXVK_OVERRIDE_DLLS=("d3d11" "dxgi")

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source config reader for defaults
# shellcheck source=config_reader.sh
source "${SCRIPT_DIR}/config_reader.sh"

DRY_RUN=0
PREFIX="${NN_PREFIX}"
RESOLUTION="${NN_RESOLUTION}"
CLEANUP_DIRS=()
DXVK_TARBALL_URL=""

usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

Provision a Wine prefix with DXVK for running EverQuest under Wine.

Options:
  --dry-run           Print every action without touching the filesystem
  --prefix PATH       Set WINEPREFIX (default: ~/.wine-eq)
  --resolution WxH    Virtual desktop resolution (default: 1920x1080)
  -h, --help          Show this help message

Examples:
  ${SCRIPT_NAME}
  ${SCRIPT_NAME} --dry-run
  ${SCRIPT_NAME} --prefix ~/my-wine --resolution 2560x1440
EOF
    exit 0
}

run() {
    if [[ "${DRY_RUN}" -eq 1 ]]; then
        nn_log "[DRY-RUN] $*"
    else
        nn_log "[RUN] $*"
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
                if [[ $# -lt 2 ]]; then
                    nn_log "ERROR: --prefix requires a value"
                    exit 1
                fi
                PREFIX="$2"
                shift 2
                ;;
            --resolution)
                if [[ $# -lt 2 ]]; then
                    nn_log "ERROR: --resolution requires a value"
                    exit 1
                fi
                RESOLUTION="$2"
                shift 2
                ;;
            -h|--help)
                usage
                ;;
            *)
                nn_log "ERROR: Unknown option: $1"
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
    nn_log "Validating dependencies..."
    local missing=()

    if [[ -z "${NN_WINE_CMD}" ]]; then
        missing+=("wine64/wine")
    fi

    for cmd in vulkaninfo wget tar; do
        if ! command -v "${cmd}" &>/dev/null; then
            missing+=("${cmd}")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        nn_log "ERROR: Missing required dependencies: ${missing[*]}"
        nn_log "Install them with: make prereqs"
        nn_log "  Or manually: sudo apt install wine64 vulkan-tools wget tar"
        exit 1
    fi

    nn_log "All dependencies found (wine: ${NN_WINE_CMD})."
}

create_wineprefix() {
    nn_log "Setting up WINEPREFIX at ${PREFIX}..."

    if [[ -d "${PREFIX}" ]]; then
        nn_log "Prefix already exists, skipping init."
        return 0
    fi

    run env WINEPREFIX="${PREFIX}" WINEARCH=win64 wineboot --init
    nn_log "WINEPREFIX created."
}

install_dxvk_dlls() {
    local src_dir="$1"
    local dst_dir="$2"
    local label="$3"

    if [[ ! -d "${src_dir}" ]]; then
        nn_log "WARNING: DXVK source dir ${src_dir} not found, skipping ${label}."
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
                nn_log "${dll} already in ${label}, skipping."
                continue
            fi
        fi

        nn_log "Installing ${dll} to ${label}..."
        cp "${src}" "${dst}"
    done
}

install_corefonts() {
    local fonts_dir="${PREFIX}/drive_c/windows/Fonts"
    if [[ -f "${fonts_dir}/arial.ttf" ]]; then
        nn_log "Core fonts already installed, skipping."
        return 0
    fi
    if ! command -v winetricks &>/dev/null; then
        nn_log "WARNING: winetricks not found, skipping core fonts."
        nn_log "  Install with: sudo apt install winetricks"
        return 0
    fi
    nn_log "Installing Microsoft core fonts (winetricks warnings are normal)..."
    # winetricks may exit non-zero due to harmless registration warnings
    run env WINEPREFIX="${PREFIX}" winetricks -q corefonts || true
    if [[ -f "${fonts_dir}/arial.ttf" ]]; then
        nn_log "Core fonts installed successfully."
    else
        nn_log "WARNING: Core font installation may have failed. Run manually:"
        nn_log "  WINEPREFIX=${PREFIX} winetricks -q corefonts"
    fi
}

download_and_install_dxvk() {
    nn_log "Downloading latest DXVK release..."

    local api_output
    api_output="$(wget -qO- "${DXVK_API_URL}" 2>&1)" || true

    local tarball_url
    # Portable grep (no -P/Perl required): extract the full URL from the JSON field
    tarball_url="$(printf '%s' "${api_output}" \
        | grep -o '"browser_download_url"[^"]*"[^"]*\.tar\.gz"' \
        | head -1 \
        | grep -o 'https://[^"]*')" || true

    if [[ -z "${tarball_url}" ]]; then
        if printf '%s' "${api_output}" | grep -qi "rate limit\|API rate"; then
            nn_log "ERROR: GitHub API rate limit exceeded."
            nn_log "Set GITHUB_TOKEN in your environment and try again:"
            nn_log "  export GITHUB_TOKEN=ghp_your_token_here"
        else
            nn_log "ERROR: Could not determine DXVK download URL from GitHub API."
        fi
        exit 1
    fi

    DXVK_TARBALL_URL="${tarball_url}"
    nn_log "DXVK tarball URL: ${tarball_url}"

    local tmpdir
    tmpdir="$(mktemp -d)"
    CLEANUP_DIRS+=("${tmpdir}")

    local tarball="${tmpdir}/dxvk.tar.gz"
    run wget -q -O "${tarball}.tmp" "${tarball_url}" && mv "${tarball}.tmp" "${tarball}"

    if [[ "${DRY_RUN}" -eq 1 ]]; then
        nn_log "[DRY-RUN] Would extract ${tarball} to ${tmpdir}"
        nn_log "[DRY-RUN] Would copy DXVK DLLs to ${PREFIX}/drive_c/windows/system32/"
        return 0
    fi

    tar -xzf "${tarball}" -C "${tmpdir}"

    local dxvk_dir
    dxvk_dir="$(find "${tmpdir}" -maxdepth 1 -type d -name 'dxvk-*' | head -n 1)"
    if [[ -z "${dxvk_dir}" ]]; then
        nn_log "ERROR: Could not find extracted DXVK directory."
        exit 1
    fi

    # Install x64 DLLs to system32 and x32 DLLs to syswow64
    # Both are needed: EQ game is 64-bit, but LaunchPad.exe/CEF is 32-bit
    install_dxvk_dlls "${dxvk_dir}/x64" "${PREFIX}/drive_c/windows/system32" "system32 (x64)"
    install_dxvk_dlls "${dxvk_dir}/x32" "${PREFIX}/drive_c/windows/syswow64" "syswow64 (x32)"

    nn_log "DXVK DLLs installed (x64 + x32)."
}

configure_dxvk_overrides() {
    nn_log "Configuring DXVK DLL overrides..."

    for dll in "${DXVK_OVERRIDE_DLLS[@]}"; do
        run env WINEPREFIX="${PREFIX}" "${NN_WINE_CMD}" reg add \
            'HKEY_CURRENT_USER\Software\Wine\DllOverrides' \
            /v "${dll}" /d native /f
    done

    nn_log "DLL overrides configured."
}

enable_virtual_desktop() {
    nn_log "Enabling virtual desktop at ${RESOLUTION}..."

    local width height
    width="${RESOLUTION%%x*}"
    height="${RESOLUTION##*x}"

    local desktop_key='HKEY_CURRENT_USER\Software\Wine\Explorer\Desktops'
    run env WINEPREFIX="${PREFIX}" "${NN_WINE_CMD}" reg add "${desktop_key}" \
        /v Default /d "${width}x${height}" /f

    local explorer_key='HKEY_CURRENT_USER\Software\Wine\Explorer'
    run env WINEPREFIX="${PREFIX}" "${NN_WINE_CMD}" reg add "${explorer_key}" \
        /v Desktop /d Default /f

    nn_log "Virtual desktop enabled (${RESOLUTION})."
}

fix_mouse_capture() {
    nn_log "Configuring mouse capture for camera rotation..."
    run env WINEPREFIX="${PREFIX}" "${NN_WINE_CMD}" reg add \
        'HKEY_CURRENT_USER\Software\Wine\DirectInput' \
        /v MouseWarpOverride /d enable /f
    nn_log "Mouse capture configured."
}

install_everquest() {
    local eq_dir="${PREFIX}/drive_c/EverQuest"
    local eq_setup_url="https://launch.daybreakgames.com/installer/EQ_setup.exe"
    local eq_setup="/tmp/EQ_setup.exe"

    if [[ -f "${eq_dir}/LaunchPad.exe" ]]; then
        nn_log "EverQuest already installed at ${eq_dir}, skipping."
        return 0
    fi

    nn_log "Installing EverQuest..."

    if [[ ! -f "${eq_setup}" ]]; then
        nn_log "Downloading EQ installer..."
        run wget -q -O "${eq_setup}.tmp" "${eq_setup_url}" && mv "${eq_setup}.tmp" "${eq_setup}"
    else
        nn_log "EQ installer already downloaded, reusing."
    fi

    if [[ "${DRY_RUN}" -eq 1 ]]; then
        nn_log "[DRY-RUN] Would run EQ_setup.exe /S /D=C:\\EverQuest"
        return 0
    fi

    nn_log "Running silent install (this may take a moment)..."
    run env WINEPREFIX="${PREFIX}" "${NN_WINE_CMD}" "${eq_setup}" /S /D='C:\EverQuest'
    sleep 5

    if [[ -f "${eq_dir}/LaunchPad.exe" ]]; then
        nn_log "EverQuest installed successfully at ${eq_dir}"
        fix_desktop_shortcut
    else
        nn_log "WARNING: LaunchPad.exe not found after install. Check manually."
    fi
}

fix_desktop_shortcut() {
    nn_log "Fixing desktop shortcut (adding --disable-gpu)..."
    local desktop_dir="${PREFIX}/drive_c/users/${USER}/Desktop"

    if [[ "${DRY_RUN}" -eq 1 ]]; then
        nn_log "  [DRY-RUN] Would fix desktop shortcut"
        return 0
    fi

    # Fix any .desktop files that launch LaunchPad.exe without --disable-gpu
    for desktop_file in "${desktop_dir}"/*.desktop "${desktop_dir}"/.desktop; do
        [[ -f "${desktop_file}" ]] || continue
        if grep -q "LaunchPad.exe" "${desktop_file}" 2>/dev/null; then
            if ! grep -q "\-\-disable-gpu" "${desktop_file}" 2>/dev/null; then
                sed -i 's/LaunchPad\.exe.*/LaunchPad.exe --disable-gpu/' "${desktop_file}"
                nn_log "  Fixed: $(basename "${desktop_file}")"
            fi
            # Also fix the Name if it's empty
            if grep -q "^Name=$" "${desktop_file}" 2>/dev/null; then
                sed -i 's/^Name=$/Name=EverQuest/' "${desktop_file}"
            fi
        fi
    done
}

configure_eq_settings() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local configure_script="${script_dir}/configure_eq.sh"

    if [[ ! -f "${configure_script}" ]]; then
        nn_log "WARNING: configure_eq.sh not found, skipping INI configuration."
        return 0
    fi

    nn_log "Applying optimized EverQuest settings..."
    local args=("--prefix" "${PREFIX}")
    if [[ "${DRY_RUN}" -eq 1 ]]; then
        args+=("--dry-run")
    fi
    bash "${configure_script}" "${args[@]}"
}

write_state_manifest() {
    if [[ "${DRY_RUN}" -eq 1 ]]; then
        nn_log "[DRY-RUN] Would write state manifest to ${LOG_DIR}/state.json"
        return 0
    fi

    local wine_version
    wine_version="$("${NN_WINE_CMD}" --version 2>/dev/null | sed 's/wine-//')" || wine_version="unknown"

    # Extract DXVK version from the tarball filename embedded in the URL
    local dxvk_version
    dxvk_version="$(printf '%s' "${DXVK_TARBALL_URL:-}" \
        | grep -o 'dxvk-[0-9][^/]*\.tar\.gz' \
        | sed 's/dxvk-//;s/\.tar\.gz//')" || true
    if [[ -z "${dxvk_version}" ]]; then
        dxvk_version="unknown"
    fi

    local eq_installed="false"
    if [[ -f "${PREFIX}/drive_c/EverQuest/LaunchPad.exe" ]]; then
        eq_installed="true"
    fi

    local deployed_at
    deployed_at="$(date -Iseconds)"

    cat > "${LOG_DIR}/state.json" <<EOF
{
  "deployed_at": "${deployed_at}",
  "wine_version": "${wine_version}",
  "dxvk_version": "${dxvk_version}",
  "prefix_path": "${PREFIX}",
  "resolution": "${RESOLUTION}",
  "eq_installed": ${eq_installed},
  "config_profile": "${NN_PROFILE:-default}"
}
EOF
    nn_log "State manifest written to ${LOG_DIR}/state.json"
}

cleanup() {
    for dir in "${CLEANUP_DIRS[@]}"; do
        rm -rf "${dir}"
    done
}

main() {
    trap cleanup EXIT
    parse_args "$@"
    ensure_log_dir
    nn_log "=== ${SCRIPT_NAME} started ==="
    nn_log "Dry-run: ${DRY_RUN}, Prefix: ${PREFIX}, Resolution: ${RESOLUTION}"

    validate_dependencies
    create_wineprefix
    install_corefonts
    download_and_install_dxvk
    configure_dxvk_overrides
    enable_virtual_desktop
    fix_mouse_capture
    install_everquest
    configure_eq_settings
    write_state_manifest

    nn_log "=== ${SCRIPT_NAME} completed ==="
    nn_log "Run 'make doctor' to verify installation, 'make launch' to play."
}

main "$@"
