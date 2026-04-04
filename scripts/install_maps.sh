#!/usr/bin/env bash
set -euo pipefail

# install_maps.sh — Install Brewall's EverQuest map pack
#
# Brewall's maps are distributed as a ZIP from https://www.eqmaps.info/eq-map-files/
# The download requires a browser interaction, so this script handles extraction
# from an already-downloaded ZIP file.
#
# Usage:
#   bash scripts/install_maps.sh --file ~/Downloads/Brewalls-Maps.zip
#   bash scripts/install_maps.sh --file ~/Downloads/Brewalls-Maps.zip --dry-run

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config_reader.sh
source "${SCRIPT_DIR}/config_reader.sh"

PREFIX="${NN_PREFIX}"
ZIP_FILE=""
DRY_RUN=0

# ─── Helpers ──────────────────────────────────────────────────────────────────

log()  { printf '[install_maps] %s\n' "$*"; }
info() { printf '\033[36m[install_maps]\033[0m %s\n' "$*"; }
ok()   { printf '\033[32m[install_maps] ✓\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[install_maps] ⚠\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[31m[install_maps] ✗\033[0m %s\n' "$*" >&2; }

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install Brewall's EverQuest map pack into the Wine prefix.

Because the download link at https://www.eqmaps.info/eq-map-files/ requires
a browser click, download the ZIP manually first, then pass it to this script:

  1. Visit https://www.eqmaps.info/eq-map-files/ and download the ZIP
  2. Run: make maps FILE=~/Downloads/Brewalls-Maps.zip

Options:
  --file PATH     Path to the downloaded Brewall maps ZIP (required)
  --prefix PATH   Override WINEPREFIX (default from config: ${PREFIX})
  --dry-run       Show what would be done without making changes
  -h, --help      Show this help message

The maps are extracted to:
  \${PREFIX}/drive_c/EverQuest/maps/Brewall/

The script is idempotent — if maps are already installed and the file
count looks healthy (>100 .txt files), it exits successfully without
re-extracting.
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

# ─── Validation ───────────────────────────────────────────────────────────────

if [[ -z "${ZIP_FILE}" ]]; then
    err "No ZIP file specified."
    printf '\n'
    printf 'Download Brewall'\''s maps from https://www.eqmaps.info/eq-map-files/\n'
    printf 'then run:\n'
    printf '  make maps FILE=~/Downloads/Brewalls-Maps.zip\n'
    printf '\n'
    exit 1
fi

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

MAPS_DEST="${PREFIX}/drive_c/EverQuest/maps/Brewall"

# ─── Idempotency Check ────────────────────────────────────────────────────────

if [[ -d "${MAPS_DEST}" ]]; then
    existing_count="$(find "${MAPS_DEST}" -maxdepth 1 -name '*.txt' -type f 2>/dev/null | wc -l)"
    if [[ "${existing_count}" -gt 100 ]]; then
        ok "Maps already installed (${existing_count} .txt files in ${MAPS_DEST})"
        ok "Nothing to do. To re-install, remove ${MAPS_DEST} and run again."
        exit 0
    fi
    warn "Destination exists but only ${existing_count} .txt files found — re-extracting"
fi

# ─── Dry-Run Mode ─────────────────────────────────────────────────────────────

if [[ "${DRY_RUN}" -eq 1 ]]; then
    info "DRY RUN — no changes will be made"
    info "Would create directory: ${MAPS_DEST}"
    info "Would extract ZIP: ${ZIP_FILE}"
    map_count="$(unzip -l "${ZIP_FILE}" 2>/dev/null | grep -c '\.txt$' || true)"
    info "ZIP contains approximately ${map_count} .txt files"
    exit 0
fi

# ─── Extraction ───────────────────────────────────────────────────────────────

eq_dir="${PREFIX}/drive_c/EverQuest"
if [[ ! -d "${eq_dir}" ]]; then
    err "EverQuest directory not found at ${eq_dir}"
    err "Run 'make deploy' first to set up the Wine prefix and install EQ."
    exit 1
fi

info "Creating maps directory: ${MAPS_DEST}"
mkdir -p "${MAPS_DEST}"

info "Extracting ${ZIP_FILE} ..."

# Detect ZIP structure: some Brewall ZIPs have a top-level folder, others
# put .txt files at the root. We use a temp dir and flatten to be safe.
TMPDIR_EXTRACT="$(mktemp -d)"
trap 'rm -rf "${TMPDIR_EXTRACT}"' EXIT

unzip -q "${ZIP_FILE}" -d "${TMPDIR_EXTRACT}"

# Find all .txt files in the extracted tree and copy to destination
txt_count=0
while IFS= read -r -d '' txt_file; do
    cp "${txt_file}" "${MAPS_DEST}/"
    txt_count=$((txt_count + 1))
done < <(find "${TMPDIR_EXTRACT}" -name '*.txt' -type f -print0)

if [[ "${txt_count}" -eq 0 ]]; then
    err "No .txt map files found in ${ZIP_FILE}"
    err "Verify this is a valid Brewall maps ZIP from https://www.eqmaps.info/eq-map-files/"
    exit 1
fi

ok "Extracted ${txt_count} map files to ${MAPS_DEST}"
ok "Brewall maps installed successfully."
log ""
log "EverQuest map path (in-game): maps/Brewall"
log "Configure your map overlay to load from this directory."
