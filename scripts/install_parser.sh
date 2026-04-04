#!/usr/bin/env bash
set -euo pipefail

# install_parser.sh — Install EQLogParser (DPS meter + trigger system)
#
# EQLogParser is a .NET 8 application that replaces GINA on Linux.
# It requires the .NET 8.0 Desktop Runtime to be installed via Wine.
#
# Because winetricks dotnetdesktop8 is fragile, this script takes a
# manual-assist approach:
#
#   Without --file: Print download instructions and the exact Wine
#                   commands needed to install .NET 8 and EQLogParser.
#
#   With --file:    Extract the provided EQLogParser ZIP into the Wine
#                   prefix's Program Files\EQLogParser\.
#
# Usage:
#   bash scripts/install_parser.sh                              # print instructions
#   bash scripts/install_parser.sh --file ~/Downloads/EQLogParser.zip
#   bash scripts/install_parser.sh --file ~/Downloads/EQLogParser.zip --dry-run

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config_reader.sh
source "${SCRIPT_DIR}/config_reader.sh"

PREFIX="${NN_PREFIX}"
ZIP_FILE=""
DRY_RUN=0

# EQLogParser GitHub releases page (for instructions)
EQLP_RELEASES="https://github.com/kauffman12/EQLogParser/releases"
# .NET 8.0 Desktop Runtime download page (for instructions)
DOTNET8_URL="https://dotnet.microsoft.com/en-us/download/dotnet/8.0"

# ─── Helpers ──────────────────────────────────────────────────────────────────

info() { printf '\033[36m[install_parser]\033[0m %s\n' "$*"; }
ok()   { printf '\033[32m[install_parser] ✓\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[install_parser] ⚠\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[31m[install_parser] ✗\033[0m %s\n' "$*" >&2; }

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install EQLogParser (DPS meter + trigger system) into the Wine prefix.

EQLogParser requires the .NET 8.0 Desktop Runtime.  Because automated
.NET 8 installation via winetricks is unreliable, this script provides
clear manual-installation instructions or handles ZIP extraction when
you supply a pre-downloaded archive.

  Without --file:
    Print step-by-step download and Wine installation instructions.

  With --file PATH:
    Extract the downloaded EQLogParser ZIP into:
      \${PREFIX}/drive_c/Program Files/EQLogParser/

Options:
  --file PATH     Path to a downloaded EQLogParser ZIP (from GitHub releases)
  --prefix PATH   Override WINEPREFIX (default from config: ${PREFIX})
  --dry-run       Show what would be done without making changes
  -h, --help      Show this help message

Download links:
  EQLogParser releases : ${EQLP_RELEASES}
  .NET 8 Desktop x64   : ${DOTNET8_URL}

Note: On Linux/Wine, Windows TTS is unavailable.  EQLogParser bundles
Piper TTS as an alternative — enable it in the Triggers configuration.
EOF
    exit 0
}

# ─── Argument Parsing ─────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case "$1" in
        --file)
            if [[ $# -lt 2 ]]; then
                err "--file requires a value"
                exit 1
            fi
            ZIP_FILE="$2"
            shift 2
            ;;
        --prefix)
            if [[ $# -lt 2 ]]; then
                err "--prefix requires a value"
                exit 1
            fi
            PREFIX="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            err "Unknown option: $1"
            usage
            ;;
    esac
done

# ─── Derive paths ─────────────────────────────────────────────────────────────

PARSER_DEST="${PREFIX}/drive_c/Program Files/EQLogParser"
PARSER_EXE="${PARSER_DEST}/EQLogParser.exe"

# ─── Already-installed check ──────────────────────────────────────────────────

if [[ -f "${PARSER_EXE}" ]]; then
    ok "EQLogParser is already installed: ${PARSER_EXE}"
    ok "Nothing to do.  To reinstall, remove '${PARSER_DEST}' and run again."
    exit 0
fi

# ─── No file supplied — print instructions ────────────────────────────────────

if [[ -z "${ZIP_FILE}" ]]; then
    cat <<EOF

EQLogParser is not yet installed.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Step 1 — Download .NET 8.0 Desktop Runtime (Windows x64 installer)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ${DOTNET8_URL}

  Select: .NET Desktop Runtime 8.x.x  →  Installers  →  x64 (Windows)
  File:   windowsdesktop-runtime-8.x.x-win-x64.exe

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Step 2 — Install .NET 8 into the Wine prefix
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  WINEPREFIX="${PREFIX}" wine ~/Downloads/windowsdesktop-runtime-8.x.x-win-x64.exe /quiet /norestart

  Tip: Run without /quiet first to watch for errors; add /quiet for
  unattended installs once you confirm it works.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Step 3 — Download EQLogParser
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ${EQLP_RELEASES}

  Download the latest ZIP asset (e.g. EQLogParser-X.Y.Z.zip).
  No installer needed — it is a self-contained directory.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Step 4 — Extract EQLogParser using this script
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  make parser PARSER_FILE=~/Downloads/EQLogParser-X.Y.Z.zip

  Or directly:
  bash scripts/install_parser.sh --file ~/Downloads/EQLogParser-X.Y.Z.zip

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Step 5 — Launch EQLogParser
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  WINEPREFIX="${PREFIX}" wine "${PARSER_EXE}"

  In EQLogParser → Settings → Triggers, enable "Use Piper TTS" so that
  trigger audio works on Linux (Windows TTS is unavailable under Wine).

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF
    exit 0
fi

# ─── File provided — validate and extract ────────────────────────────────────

# Expand tilde manually (safe alternative to eval)
ZIP_FILE="${ZIP_FILE/#\~/$HOME}"

if [[ ! -f "${ZIP_FILE}" ]]; then
    err "ZIP file not found: ${ZIP_FILE}"
    exit 1
fi

if ! command -v unzip &>/dev/null; then
    err "unzip not found — install it with: sudo apt install unzip"
    exit 1
fi

eq_dir="${PREFIX}/drive_c/EverQuest"
if [[ ! -d "${eq_dir}" ]]; then
    warn "EverQuest directory not found at ${eq_dir}"
    warn "EQLogParser can still be installed but won't find EQ logs automatically."
    warn "Run 'make deploy' to set up the Wine prefix and install EQ."
fi

# Verify the ZIP contains EQLogParser.exe
if ! unzip -l "${ZIP_FILE}" 2>/dev/null | grep -q 'EQLogParser\.exe'; then
    err "EQLogParser.exe not found in ${ZIP_FILE}"
    err "Verify this is a valid EQLogParser ZIP from ${EQLP_RELEASES}"
    exit 1
fi

# ─── Dry-Run Mode ─────────────────────────────────────────────────────────────

if [[ "${DRY_RUN}" -eq 1 ]]; then
    info "DRY RUN — no changes will be made"
    info "Would create directory: ${PARSER_DEST}"
    info "Would extract ZIP: ${ZIP_FILE}"
    file_count="$(unzip -l "${ZIP_FILE}" 2>/dev/null | tail -1 | awk '{print $2}' || true)"
    info "ZIP contains approximately ${file_count} files"
    exit 0
fi

# ─── Extraction ───────────────────────────────────────────────────────────────

info "Creating destination: ${PARSER_DEST}"
mkdir -p "${PARSER_DEST}"

info "Extracting ${ZIP_FILE} ..."

TMPDIR_EXTRACT="$(mktemp -d)"
trap 'rm -rf "${TMPDIR_EXTRACT}"' EXIT

unzip -q "${ZIP_FILE}" -d "${TMPDIR_EXTRACT}"

# EQLogParser ZIPs may place files at the root or inside a single top-level
# directory.  Detect and flatten: find EQLogParser.exe and use its parent.
src_dir=""
while IFS= read -r -d '' exe_path; do
    src_dir="$(dirname "${exe_path}")"
    break
done < <(find "${TMPDIR_EXTRACT}" -maxdepth 2 -name 'EQLogParser.exe' -print0)

if [[ -z "${src_dir}" ]]; then
    err "EQLogParser.exe not found after extraction — unexpected ZIP layout"
    exit 1
fi

# Copy all files from the detected source directory
file_count=0
while IFS= read -r -d '' src_file; do
    rel_path="${src_file#"${src_dir}/"}"
    dest_file="${PARSER_DEST}/${rel_path}"
    dest_subdir="$(dirname "${dest_file}")"
    mkdir -p "${dest_subdir}"
    cp "${src_file}" "${dest_file}"
    file_count=$((file_count + 1))
done < <(find "${src_dir}" -type f -print0)

if [[ "${file_count}" -eq 0 ]]; then
    err "No files extracted from ${ZIP_FILE}"
    exit 1
fi

ok "Extracted ${file_count} files to ${PARSER_DEST}"
ok "EQLogParser installed successfully."
nn_log ""
nn_log "To launch EQLogParser:"
nn_log "  WINEPREFIX=\"${PREFIX}\" wine \"${PARSER_EXE}\""
nn_log ""
nn_log "NOTE: .NET 8.0 Desktop Runtime must be installed separately."
nn_log "If not yet installed, see instructions:"
nn_log "  bash scripts/install_parser.sh --help"
nn_log ""
nn_log "Piper TTS: Enable in EQLogParser → Settings → Triggers → Use Piper TTS"
nn_log "(Windows TTS is unavailable under Wine)"
