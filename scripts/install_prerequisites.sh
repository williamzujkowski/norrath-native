#!/usr/bin/env bash
set -euo pipefail

# install_prerequisites.sh — Install all system dependencies for norrath-native
# Requires: Ubuntu 24.04 LTS, sudo access
# Idempotent: safe to run multiple times

SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_NAME
readonly LOG_DIR="${HOME}/.local/share/norrath-native"
readonly MIN_WINE_VERSION="11.0"

# Required packages for Wine + Vulkan on Ubuntu 24.04
# Wine is installed from WineHQ repo (see install_wine_from_winehq)
readonly -a REQUIRED_PACKAGES=(
    # Vulkan drivers and tools
    mesa-vulkan-drivers
    "mesa-vulkan-drivers:i386"
    libvulkan1
    "libvulkan1:i386"
    vulkan-tools
    # Wine dependencies
    cabextract
    winbind
    # X11 utilities (xprop for PID lookup, xrandr for display detection)
    x11-utils
    # Download and extraction tools
    wget
    tar
)

# Optional but recommended packages
readonly -a OPTIONAL_PACKAGES=(
    # Better font rendering in Wine
    fonts-liberation
    fonts-wine
    # Wine tools
    winetricks
    # Window management extras
    wmctrl
    scrot
    # Database tools (for session inspection)
    sqlite3
    # MinGW compiler (only needed for development — wine_helper.exe ships pre-built)
    gcc-mingw-w64
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

run() {
    if [[ "${DRY_RUN}" -eq 1 ]]; then
        nn_log "[DRY-RUN] $*"
    else
        nn_log "Running: $*"
        "$@"
    fi
}

check_ubuntu() {
    if [[ ! -f /etc/os-release ]]; then
        nn_log "ERROR: Cannot detect OS. This script requires Ubuntu 24.04 LTS."
        exit 1
    fi

    local version_id
    version_id=$(grep '^VERSION_ID=' /etc/os-release | cut -d'"' -f2)

    if [[ "${version_id}" != "24.04" ]]; then
        nn_log "WARNING: Detected Ubuntu ${version_id}, but this script targets 24.04 LTS."
        nn_log "Proceeding anyway — packages may differ on other versions."
    fi
}

check_sudo() {
    if [[ "${DRY_RUN}" -eq 1 ]]; then
        return 0
    fi

    if ! sudo -n true 2>/dev/null; then
        nn_log "This script requires sudo access to install system packages."
        nn_log "You may be prompted for your password."
    fi
}

# ─── Installation Steps ──────────────────────────────────────────────────────

enable_i386() {
    nn_log "Enabling 32-bit (i386) architecture..."
    if dpkg --print-foreign-architectures 2>/dev/null | grep -q "i386"; then
        nn_log "  i386 architecture already enabled, skipping"
    else
        run sudo dpkg --add-architecture i386
        run sudo apt-get update -qq
    fi
}

install_wine_from_winehq() {
    nn_log "Setting up WineHQ repository for Wine 11..."

    # Check if Wine 11+ is already installed
    if command -v wine &>/dev/null; then
        local current_version
        current_version="$(wine --version 2>/dev/null | sed 's/wine-//' | cut -d'.' -f1)"
        if [[ "${current_version}" -ge 11 ]] 2>/dev/null; then
            nn_log "  Wine ${current_version}.x already installed, skipping"
            return 0
        fi
    fi

    # Add WineHQ signing key
    if [[ ! -f /etc/apt/keyrings/winehq-archive.key ]]; then
        nn_log "  Adding WineHQ signing key..."
        run sudo mkdir -pm755 /etc/apt/keyrings
        run sudo wget -qO /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
    fi

    # Add WineHQ repository for Ubuntu 24.04 (Noble)
    if [[ ! -f /etc/apt/sources.list.d/winehq-noble.sources ]]; then
        nn_log "  Adding WineHQ Noble repository..."
        run sudo wget -qNP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/noble/winehq-noble.sources
        run sudo apt-get update -qq
    fi

    nn_log "  Installing winehq-stable..."
    run sudo apt-get install -y --install-recommends winehq-stable
}

install_packages() {
    local -a packages=("$@")
    local -a to_install=()

    for pkg in "${packages[@]}"; do
        if dpkg -l "${pkg}" 2>/dev/null | grep -q "^ii"; then
            nn_log "  Already installed: ${pkg}"
        else
            to_install+=("${pkg}")
        fi
    done

    if [[ ${#to_install[@]} -eq 0 ]]; then
        nn_log "  All packages already installed"
        return 0
    fi

    nn_log "  Installing: ${to_install[*]}"
    run sudo apt-get install -y "${to_install[@]}"
}

verify_wine() {
    nn_log "Verifying Wine installation..."

    if ! command -v wine &>/dev/null; then
        nn_log "ERROR: wine not found after installation"
        return 1
    fi

    local wine_version
    wine_version=$(wine --version 2>/dev/null | sed 's/wine-//')
    nn_log "  Wine version: ${wine_version}"

    # Simple version floor check (compare major.minor)
    local major minor
    major=$(echo "${wine_version}" | cut -d'.' -f1)
    minor=$(echo "${wine_version}" | cut -d'.' -f2)
    local min_major min_minor
    min_major=$(echo "${MIN_WINE_VERSION}" | cut -d'.' -f1)
    min_minor=$(echo "${MIN_WINE_VERSION}" | cut -d'.' -f2)

    if [[ "${major}" -lt "${min_major}" ]] || { [[ "${major}" -eq "${min_major}" ]] && [[ "${minor}" -lt "${min_minor}" ]]; }; then
        nn_log "WARNING: Wine ${wine_version} is below minimum ${MIN_WINE_VERSION}"
        nn_log "Consider installing from the WineHQ repository for a newer version."
    else
        nn_log "  Wine version meets minimum requirement (>= ${MIN_WINE_VERSION})"
    fi
}

verify_vulkan() {
    nn_log "Verifying Vulkan support..."

    if ! command -v vulkaninfo &>/dev/null; then
        nn_log "ERROR: vulkaninfo not found after installation"
        return 1
    fi

    local device_name
    device_name=$(vulkaninfo --summary 2>/dev/null | grep "deviceName" | head -1 | sed 's/.*= //' || true)

    if [[ -z "${device_name}" ]]; then
        nn_log "WARNING: No Vulkan device detected. Your GPU may not support Vulkan."
        nn_log "  Intel: sudo apt install mesa-vulkan-drivers"
        nn_log "  NVIDIA: Install proprietary drivers with Vulkan support"
        nn_log "  AMD: sudo apt install mesa-vulkan-drivers"
    else
        nn_log "  Vulkan device: ${device_name}"
    fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)     DRY_RUN=1; shift ;;
            --skip-optional) SKIP_OPTIONAL=1; shift ;;
            -h|--help)     usage; exit 0 ;;
            *)             nn_log "Unknown option: $1"; usage; exit 1 ;;
        esac
    done

    mkdir -p "${LOG_DIR}"
    nn_log "=== install_prerequisites.sh started ==="
    nn_log "Dry-run: ${DRY_RUN}, Skip-optional: ${SKIP_OPTIONAL}"

    check_ubuntu
    check_sudo

    nn_log ""
    nn_log "Step 1/5: Enable 32-bit architecture"
    enable_i386

    nn_log ""
    nn_log "Step 2/6: Install Wine 11 from WineHQ"
    install_wine_from_winehq

    nn_log ""
    nn_log "Step 3/6: Update package lists"
    run sudo apt-get update -qq

    nn_log ""
    nn_log "Step 4/6: Install required packages"
    install_packages "${REQUIRED_PACKAGES[@]}"

    if [[ "${SKIP_OPTIONAL}" -eq 0 ]]; then
        nn_log ""
        nn_log "Step 5/6: Install optional packages"
        install_packages "${OPTIONAL_PACKAGES[@]}"
    else
        nn_log ""
        nn_log "Step 5/6: Skipping optional packages (--skip-optional)"
    fi

    if [[ "${DRY_RUN}" -eq 0 ]]; then
        nn_log ""
        nn_log "Step 6/6: Verify installation"
        verify_wine
        verify_vulkan
    else
        nn_log ""
        nn_log "Step 5/5: Skipping verification (dry-run mode)"
    fi

    nn_log ""
    nn_log "=== Prerequisites installation complete ==="
    nn_log "Next step: make deploy"
}

main "$@"
