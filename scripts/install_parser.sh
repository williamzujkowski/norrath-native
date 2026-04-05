#!/usr/bin/env bash
set -euo pipefail

# install_parser.sh — Install EQLogParser (DPS meter + trigger system)
#
# EQLogParser is a .NET 8 application that replaces GINA on Linux.
# It requires the .NET 8.0 Desktop Runtime to be installed via Wine.
#
# This script downloads the installer from GitHub and runs it via Wine.
# The PiperTTS variant is used by default (Windows TTS doesn't work under Wine).
#
# Usage:
#   bash scripts/install_parser.sh                  # Download + install
#   bash scripts/install_parser.sh --file FILE.exe  # Install from local file
#   bash scripts/install_parser.sh --dotnet         # Install .NET 8 runtime only

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config_reader.sh
source "${SCRIPT_DIR}/config_reader.sh"

# EQLogParser gets its own Wine prefix to isolate it from EQ's
# registry settings (GrabFullscreen, Decorated=N, Managed=N) which
# cause focus-stealing and window management issues for WPF apps.
PARSER_PREFIX="${HOME}/.wine-eqlogparser"
LOCAL_FILE=""
DRY_RUN=0
DOTNET_ONLY=0

EQLP_REPO="kauffman12/EQLogParser"
PARSER_DEST="${PARSER_PREFIX}/drive_c/Program Files/EQLogParser"
PARSER_EXE="${PARSER_DEST}/EQLogParser.exe"

# ─── Helpers ──────────────────────────────────────────────────────────────────

info() { printf '\033[36m[parser]\033[0m %s\n' "$*"; }
ok()   { printf '\033[32m[parser] ✓\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[parser] ⚠\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[31m[parser] ✗\033[0m %s\n' "$*" >&2; }

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install EQLogParser (DPS meter + trigger system) into the Wine prefix.

Downloads the latest release from GitHub and runs the installer via Wine.
Uses the PiperTTS variant (Windows TTS doesn't work under Wine).

Prerequisites: .NET 8.0 Desktop Runtime must be installed first.
  Run: $(basename "$0") --dotnet

Options:
  --file PATH     Install from a local .exe instead of downloading
  --dotnet        Download and install .NET 8 Desktop Runtime only
  --update        Force reinstall even if already installed
  --prefix PATH   Override WINEPREFIX (default: ${PREFIX})
  --dry-run       Show what would be done without making changes
  -h, --help      Show this help

Examples:
  make parser                              # Full auto-install
  make parser PARSER_FILE=~/Downloads/EQLogParser-install-2.3.49.exe
EOF
    exit 0
}

# ─── Argument Parsing ─────────────────────────────────────────────────────────

FORCE_UPDATE=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --file)
            if [[ $# -lt 2 ]]; then err "--file requires a value"; exit 1; fi
            LOCAL_FILE="$2"; shift 2 ;;
        --dotnet) DOTNET_ONLY=1; shift ;;
        --update) FORCE_UPDATE=1; shift ;;
        --prefix)
            if [[ $# -lt 2 ]]; then err "--prefix requires a value"; exit 1; fi
            PARSER_PREFIX="$2"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help) usage ;;
        *) err "Unknown option: $1"; usage ;;
    esac
done

# ─── Prefix Setup ────────────────────────────────────────────────────────────

setup_parser_prefix() {
    if [[ -d "${PARSER_PREFIX}" ]]; then
        return 0
    fi

    info "Creating parser Wine prefix at ${PARSER_PREFIX}..."
    WINEPREFIX="${PARSER_PREFIX}" WINEARCH=win64 wineboot --init 2>/dev/null

    # Disable DWM composition (prevents WPF crash on minimize)
    WINEPREFIX="${PARSER_PREFIX}" wine reg add \
        'HKEY_CURRENT_USER\Software\Wine\DWM' \
        /v DisableComposition /d Y /f 2>/dev/null

    # Install Microsoft core fonts (WPF crashes without fonts to render text)
    if command -v winetricks &>/dev/null; then
        info "Installing core fonts..."
        WINEPREFIX="${PARSER_PREFIX}" winetricks -q corefonts 2>/dev/null || true
    fi

    info "Parser prefix created."
}

# ─── .NET 8 Runtime Installation ─────────────────────────────────────────────

install_dotnet() {
    info "Checking for .NET 8 Desktop Runtime..."

    # Ensure Wine Mono is installed (prevents interactive dialog)
    if [[ ! -d "${PARSER_PREFIX}/drive_c/windows/mono" ]]; then
        info "Installing Wine Mono first..."
        WINEPREFIX="${PARSER_PREFIX}" DISPLAY="" wineboot --update 2>/dev/null || true
    fi

    # Check if already installed
    if WINEPREFIX="${PARSER_PREFIX}" wine dotnet --list-runtimes 2>/dev/null | grep -q 'Microsoft.WindowsDesktop.App 8'; then
        ok ".NET 8 Desktop Runtime already installed"
        return 0
    fi

    info "Downloading .NET 8.0 Desktop Runtime..."
    # aka.ms redirect always points to the latest .NET 8.x patch release
    local dotnet_url="https://aka.ms/dotnet/8.0/windowsdesktop-runtime-win-x64.exe"
    local dotnet_file
    dotnet_file="$(mktemp --suffix=.exe)"
    trap 'rm -f "${dotnet_file}"' RETURN

    wget -q --show-progress -O "${dotnet_file}" "${dotnet_url}" 2>&1

    info "Installing .NET 8 Desktop Runtime (this may take a few minutes)..."
    if [[ "${DRY_RUN}" -eq 1 ]]; then
        info "[DRY-RUN] Would run: wine ${dotnet_file} /quiet /norestart"
        return 0
    fi

    WINEPREFIX="${PARSER_PREFIX}" wine "${dotnet_file}" /quiet /norestart 2>/dev/null || true
    ok ".NET 8 Desktop Runtime installed"
}

if [[ "${DOTNET_ONLY}" -eq 1 ]]; then
    setup_parser_prefix
    install_dotnet
    exit 0
fi

# ─── Setup prefix and ensure .NET 8 is installed ────────────────────────────
# Parser gets its own prefix to avoid EQ's focus-stealing settings.

setup_parser_prefix

install_dotnet

# ─── Idempotency Check ──────────────────────────────────────────────────────

if [[ "${FORCE_UPDATE}" -eq 0 ]] && [[ -f "${PARSER_EXE}" ]]; then
    ok "EQLogParser already installed at ${PARSER_DEST}"
    ok "Run with --update to force reinstall."
    exit 0
fi

# ─── Dry-Run Mode ────────────────────────────────────────────────────────────

if [[ "${DRY_RUN}" -eq 1 ]]; then
    info "DRY RUN — no changes will be made"
    if [[ -n "${LOCAL_FILE}" ]]; then
        info "Would install from: ${LOCAL_FILE}"
    else
        info "Would download latest EQLogParser from: https://github.com/${EQLP_REPO}/releases"
    fi
    info "Would install to: ${PARSER_DEST}"
    exit 0
fi

# ─── Get Installer ───────────────────────────────────────────────────────────

installer_path=""

if [[ -n "${LOCAL_FILE}" ]]; then
    LOCAL_FILE="${LOCAL_FILE/#\~/$HOME}"
    if [[ ! -f "${LOCAL_FILE}" ]]; then
        err "File not found: ${LOCAL_FILE}"
        exit 1
    fi
    installer_path="${LOCAL_FILE}"
    info "Using local installer: ${installer_path}"
else
    # Download latest release from GitHub (prefer pipertts variant)
    info "Fetching latest release from GitHub..."
    local_download_url=""
    local_download_url="$(gh api "repos/${EQLP_REPO}/releases/latest" \
        --jq '.assets[] | select(.name | contains("pipertts")) | .browser_download_url' 2>/dev/null || true)"

    if [[ -z "${local_download_url}" ]]; then
        # Fallback to non-pipertts variant
        local_download_url="$(gh api "repos/${EQLP_REPO}/releases/latest" \
            --jq '.assets[0].browser_download_url' 2>/dev/null || true)"
    fi

    if [[ -z "${local_download_url}" ]]; then
        err "Could not find EQLogParser release on GitHub."
        err "Download manually from: https://github.com/${EQLP_REPO}/releases"
        err "Then run: make parser PARSER_FILE=~/Downloads/EQLogParser-install-X.Y.Z.exe"
        exit 1
    fi

    filename="$(basename "${local_download_url}")"
    installer_path="$(mktemp --suffix="-${filename}")"
    trap 'rm -f "${installer_path}"' EXIT

    info "Downloading: ${filename}"
    wget -q --show-progress -O "${installer_path}" "${local_download_url}" 2>&1
fi

# ─── Install ─────────────────────────────────────────────────────────────────

info "Installing EQLogParser via Wine (silent)..."

# Inno Setup flags: /VERYSILENT suppresses UI, /SUPPRESSMSGBOXES skips prompts,
# /DIR= sets install path within the parser prefix
WINEPREFIX="${PARSER_PREFIX}" wine "${installer_path}" \
    /VERYSILENT /SUPPRESSMSGBOXES /NORESTART \
    /DIR="C:\\Program Files\\EQLogParser" 2>/dev/null || true

# Verify installation
if [[ -f "${PARSER_EXE}" ]]; then
    ok "EQLogParser installed successfully at ${PARSER_DEST}"

    # Symlink EQ directory into parser prefix so EQLogParser can find logs.
    # EQLogParser looks for logs at C:\EverQuest\Logs\ — the symlink makes
    # the EQ prefix's game files visible in the parser prefix.
    eq_dir="${NN_PREFIX}/drive_c/EverQuest"
    parser_eq_link="${PARSER_PREFIX}/drive_c/EverQuest"
    if [[ -d "${eq_dir}" ]] && [[ ! -e "${parser_eq_link}" ]]; then
        ln -sfn "${eq_dir}" "${parser_eq_link}"
        ok "Linked EQ logs into parser prefix (C:\\EverQuest\\Logs\\)"
    fi

    # Create desktop shortcut and pin to taskbar
    bash "${SCRIPT_DIR}/install_shortcuts.sh" --parser-only 2>/dev/null || true

    info ""
    info "EQLogParser pinned to your taskbar."
    info ""
    info "First launch setup:"
    info "  1. File → Open → navigate to C:\\EverQuest\\Logs\\"
    info "  2. Select eqlog_${NN_MAIN_CHARACTER:-YourCharacter}_*.txt"
    info "  3. Settings → Triggers → enable 'Use Piper TTS'"
else
    warn "EQLogParser.exe not found after installation."
    warn "The installer may have used a different path."
    warn "Check: ls '${PARSER_PREFIX}/drive_c/Program Files/'"
fi
