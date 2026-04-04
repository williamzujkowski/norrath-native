#!/usr/bin/env bash
set -euo pipefail

# install_prerequisites.sh — Install all system dependencies for norrath-native
# Requires: Ubuntu 24.04 LTS, sudo access
# Idempotent: safe to run multiple times

SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_NAME
readonly LOG_DIR="${HOME}/.local/share/norrath-native"
readonly LOG_FILE="${LOG_DIR}/install.log"
readonly MIN_WINE_VERSION="9.0"

# Required packages for 64-bit Wine + Vulkan on Ubuntu 24.04
readonly -a REQUIRED_PACKAGES=(
    # Wine (stable)
    wine64
    wine32
    # Vulkan drivers and tools
    mesa-vulkan-drivers
    "mesa-vulkan-drivers:i386"
    libvulkan1
    "libvulkan1:i386"
    vulkan-tools
    # Wine dependencies
    cabextract
    winbind
    # Download tools
    wget
    tar
)

# Optional but recommended packages
readonly -a OPTIONAL_PACKAGES=(
    # Better font rendering in Wine
    fonts-liberation
    fonts-wine
    # Debugging tools
    winetricks
)

DRY_RUN=0
SKIP_OPTIONAL=0

# ─── Helpers ──────────────────────────────────────────────────────────────────

usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

Install all system prerequisites for norrath-native (EverQuest on Linux).

Options:
    --dry-run         Show what would be installed without making changes
    --skip-optional   Skip optional packages (fonts, winetricks)
    -h, --help        Show this help message

Requires: Ubuntu 24.04 LTS, sudo access
EOF
}

log() {
    local msg
    msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg"
    if [[ -d "${LOG_DIR}" ]]; then
        echo "$msg" >> "${LOG_FILE}"
    fi
}

run() {
    if [[ "${DRY_RUN}" -eq 1 ]]; then
        log "[DRY-RUN] $*"
    else
        log "Running: $*"
        "$@"
    fi
}

check_ubuntu() {
    if [[ ! -f /etc/os-release ]]; then
        log "ERROR: Cannot detect OS. This script requires Ubuntu 24.04 LTS."
        exit 1
    fi

    local version_id
    version_id=$(grep '^VERSION_ID=' /etc/os-release | cut -d'"' -f2)

    if [[ "${version_id}" != "24.04" ]]; then
        log "WARNING: Detected Ubuntu ${version_id}, but this script targets 24.04 LTS."
        log "Proceeding anyway — packages may differ on other versions."
    fi
}

check_sudo() {
    if [[ "${DRY_RUN}" -eq 1 ]]; then
        return 0
    fi

    if ! sudo -n true 2>/dev/null; then
        log "This script requires sudo access to install system packages."
        log "You may be prompted for your password."
    fi
}

# ─── Installation Steps ──────────────────────────────────────────────────────

enable_i386() {
    log "Enabling 32-bit (i386) architecture..."
    if dpkg --print-foreign-architectures 2>/dev/null | grep -q "i386"; then
        log "  i386 architecture already enabled, skipping"
    else
        run sudo dpkg --add-architecture i386
        run sudo apt-get update -qq
    fi
}

install_packages() {
    local -a packages=("$@")
    local -a to_install=()

    for pkg in "${packages[@]}"; do
        if dpkg -l "${pkg}" 2>/dev/null | grep -q "^ii"; then
            log "  Already installed: ${pkg}"
        else
            to_install+=("${pkg}")
        fi
    done

    if [[ ${#to_install[@]} -eq 0 ]]; then
        log "  All packages already installed"
        return 0
    fi

    log "  Installing: ${to_install[*]}"
    run sudo apt-get install -y "${to_install[@]}"
}

verify_wine() {
    log "Verifying Wine installation..."

    if ! command -v wine64 &>/dev/null; then
        log "ERROR: wine64 not found after installation"
        return 1
    fi

    local wine_version
    wine_version=$(wine64 --version 2>/dev/null | sed 's/wine-//')
    log "  Wine version: ${wine_version}"

    # Simple version floor check (compare major.minor)
    local major minor
    major=$(echo "${wine_version}" | cut -d'.' -f1)
    minor=$(echo "${wine_version}" | cut -d'.' -f2)
    local min_major min_minor
    min_major=$(echo "${MIN_WINE_VERSION}" | cut -d'.' -f1)
    min_minor=$(echo "${MIN_WINE_VERSION}" | cut -d'.' -f2)

    if [[ "${major}" -lt "${min_major}" ]] || { [[ "${major}" -eq "${min_major}" ]] && [[ "${minor}" -lt "${min_minor}" ]]; }; then
        log "WARNING: Wine ${wine_version} is below minimum ${MIN_WINE_VERSION}"
        log "Consider installing from the WineHQ repository for a newer version."
    else
        log "  Wine version meets minimum requirement (>= ${MIN_WINE_VERSION})"
    fi
}

verify_vulkan() {
    log "Verifying Vulkan support..."

    if ! command -v vulkaninfo &>/dev/null; then
        log "ERROR: vulkaninfo not found after installation"
        return 1
    fi

    local device_name
    device_name=$(vulkaninfo --summary 2>/dev/null | grep "deviceName" | head -1 | sed 's/.*= //' || true)

    if [[ -z "${device_name}" ]]; then
        log "WARNING: No Vulkan device detected. Your GPU may not support Vulkan."
        log "  Intel: sudo apt install mesa-vulkan-drivers"
        log "  NVIDIA: Install proprietary drivers with Vulkan support"
        log "  AMD: sudo apt install mesa-vulkan-drivers"
    else
        log "  Vulkan device: ${device_name}"
    fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)     DRY_RUN=1; shift ;;
            --skip-optional) SKIP_OPTIONAL=1; shift ;;
            -h|--help)     usage; exit 0 ;;
            *)             log "Unknown option: $1"; usage; exit 1 ;;
        esac
    done

    mkdir -p "${LOG_DIR}"
    log "=== install_prerequisites.sh started ==="
    log "Dry-run: ${DRY_RUN}, Skip-optional: ${SKIP_OPTIONAL}"

    check_ubuntu
    check_sudo

    log ""
    log "Step 1/5: Enable 32-bit architecture"
    enable_i386

    log ""
    log "Step 2/5: Update package lists"
    run sudo apt-get update -qq

    log ""
    log "Step 3/5: Install required packages"
    install_packages "${REQUIRED_PACKAGES[@]}"

    if [[ "${SKIP_OPTIONAL}" -eq 0 ]]; then
        log ""
        log "Step 4/5: Install optional packages"
        install_packages "${OPTIONAL_PACKAGES[@]}"
    else
        log ""
        log "Step 4/5: Skipping optional packages (--skip-optional)"
    fi

    if [[ "${DRY_RUN}" -eq 0 ]]; then
        log ""
        log "Step 5/5: Verify installation"
        verify_wine
        verify_vulkan
    else
        log ""
        log "Step 5/5: Skipping verification (dry-run mode)"
    fi

    log ""
    log "=== Prerequisites installation complete ==="
    log "Next step: make deploy"
}

main "$@"
