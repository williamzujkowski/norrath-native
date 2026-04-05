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

PREFIX="${NN_PREFIX}"
LOCAL_FILE=""
DRY_RUN=0
DOTNET_ONLY=0

EQLP_REPO="kauffman12/EQLogParser"
PARSER_DEST="${PREFIX}/drive_c/Program Files/EQLogParser"
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
            PREFIX="$2"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help) usage ;;
        *) err "Unknown option: $1"; usage ;;
    esac
done

# ─── .NET 8 Runtime Installation ─────────────────────────────────────────────

install_dotnet() {
    info "Checking for .NET 8 Desktop Runtime..."

    # Check if already installed
    if WINEPREFIX="${PREFIX}" wine dotnet --list-runtimes 2>/dev/null | grep -q 'Microsoft.WindowsDesktop.App 8'; then
        ok ".NET 8 Desktop Runtime already installed"
        return 0
    fi

    info "Downloading .NET 8.0 Desktop Runtime..."
    local dotnet_url="https://download.visualstudio.microsoft.com/download/pr/f18288a0-1554-4f3a-966b-c702baa3b9dc/windowsdesktop-runtime-8.0.16-win-x64.exe"
    local dotnet_file
    dotnet_file="$(mktemp --suffix=.exe)"
    trap 'rm -f "${dotnet_file}"' RETURN

    wget -q --show-progress -O "${dotnet_file}" "${dotnet_url}" 2>&1

    info "Installing .NET 8 Desktop Runtime (this may take a few minutes)..."
    if [[ "${DRY_RUN}" -eq 1 ]]; then
        info "[DRY-RUN] Would run: wine ${dotnet_file} /quiet /norestart"
        return 0
    fi

    WINEPREFIX="${PREFIX}" wine "${dotnet_file}" /quiet /norestart 2>/dev/null || true
    ok ".NET 8 Desktop Runtime installed"
}

if [[ "${DOTNET_ONLY}" -eq 1 ]]; then
    install_dotnet
    exit 0
fi

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

info "Installing EQLogParser via Wine..."
info "  (The installer window may appear — follow its prompts)"

WINEPREFIX="${PREFIX}" wine "${installer_path}" 2>/dev/null || true

# Verify installation
if [[ -f "${PARSER_EXE}" ]]; then
    ok "EQLogParser installed successfully at ${PARSER_DEST}"
    info ""
    info "Launch with:"
    info "  WINEPREFIX=${PREFIX} wine \"${PARSER_EXE}\""
    info ""
    info "In EQLogParser → Settings → Triggers, enable 'Use Piper TTS'"
    info "for trigger audio (Windows TTS is unavailable under Wine)."
else
    warn "EQLogParser.exe not found after installation."
    warn "The installer may have used a different path."
    warn "Check: ls '${PREFIX}/drive_c/Program Files/'"
fi
