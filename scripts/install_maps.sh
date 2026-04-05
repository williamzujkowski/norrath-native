#!/usr/bin/env bash
set -euo pipefail

# install_maps.sh — Install Good's EverQuest map pack
#
# Downloads Good's maps from GitHub (RedGuides/goodurden-maps) and installs
# them into the EQ maps directory. Alternatively, install from a local ZIP.
#
# Usage:
#   bash scripts/install_maps.sh                    # Download from GitHub
#   bash scripts/install_maps.sh --file maps.zip    # Install from local ZIP

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config_reader.sh
source "${SCRIPT_DIR}/config_reader.sh"

PREFIX="${NN_PREFIX}"
ZIP_FILE=""
DRY_RUN=0

# Good's Maps — pinned to a known-good commit for supply chain safety
MAPS_REPO="https://github.com/RedGuides/goodurden-maps"
MAPS_COMMIT="709ebd7cf198b3edb2a60c0005e1cea388652c51"
MAPS_DIR_IN_REPO="Good's Maps"

# ─── Helpers ──────────────────────────────────────────────────────────────────

info() { printf '\033[36m[maps]\033[0m %s\n' "$*"; }
ok()   { printf '\033[32m[maps] ✓\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[maps] ⚠\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[31m[maps] ✗\033[0m %s\n' "$*" >&2; }

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install Good's EverQuest map pack into the Wine prefix.

By default, downloads from GitHub (RedGuides/goodurden-maps).
You can also install from a local ZIP file.

Options:
  --file PATH     Install from a local ZIP instead of downloading
  --update        Force re-download even if maps exist
  --prefix PATH   Override WINEPREFIX (default from config: ${PREFIX})
  --dry-run       Show what would be done without making changes
  -h, --help      Show this help message

Examples:
  make maps                              # Download Good's maps from GitHub
  make maps FILE=~/Downloads/custom.zip  # Install from local ZIP
EOF
    exit 0
}

# ─── Argument Parsing ─────────────────────────────────────────────────────────

FORCE_UPDATE=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --file)
            if [[ $# -lt 2 ]]; then err "--file requires a value"; exit 1; fi
            ZIP_FILE="$2"; shift 2 ;;
        --update) FORCE_UPDATE=1; shift ;;
        --prefix)
            if [[ $# -lt 2 ]]; then err "--prefix requires a value"; exit 1; fi
            PREFIX="$2"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help) usage ;;
        *) err "Unknown option: $1"; usage ;;
    esac
done

# ─── Validation ──────────────────────────────────────────────────────────────

MAPS_DEST="${PREFIX}/drive_c/EverQuest/maps"
EQ_DIR="${PREFIX}/drive_c/EverQuest"

if [[ ! -d "${EQ_DIR}" ]]; then
    err "EverQuest directory not found at ${EQ_DIR}"
    err "Run 'make deploy' first."
    exit 1
fi

# ─── Idempotency Check ──────────────────────────────────────────────────────

if [[ "${FORCE_UPDATE}" -eq 0 ]] && [[ -d "${MAPS_DEST}" ]]; then
    existing_count="$(find "${MAPS_DEST}" -maxdepth 1 -name '*.txt' -type f 2>/dev/null | wc -l)"
    if [[ "${existing_count}" -gt 100 ]]; then
        ok "Maps already installed (${existing_count} .txt files in ${MAPS_DEST})"
        ok "Run with --update to force re-download."
        exit 0
    fi
fi

# ─── Dry-Run Mode ────────────────────────────────────────────────────────────

if [[ "${DRY_RUN}" -eq 1 ]]; then
    info "DRY RUN — no changes will be made"
    if [[ -n "${ZIP_FILE}" ]]; then
        info "Would extract ZIP: ${ZIP_FILE}"
    else
        info "Would download Good's maps from: ${MAPS_REPO}"
        info "Pinned to commit: ${MAPS_COMMIT}"
    fi
    info "Would install to: ${MAPS_DEST}"
    exit 0
fi

# ─── Install from ZIP ────────────────────────────────────────────────────────

if [[ -n "${ZIP_FILE}" ]]; then
    ZIP_FILE="${ZIP_FILE/#\~/$HOME}"
    if [[ ! -f "${ZIP_FILE}" ]]; then
        err "ZIP file not found: ${ZIP_FILE}"
        exit 1
    fi
    if ! command -v unzip &>/dev/null; then
        err "unzip not found — install with: sudo apt install unzip"
        exit 1
    fi

    info "Installing from ZIP: ${ZIP_FILE}"
    mkdir -p "${MAPS_DEST}"

    TMPDIR_EXTRACT="$(mktemp -d)"
    trap 'rm -rf "${TMPDIR_EXTRACT}"' EXIT
    unzip -q "${ZIP_FILE}" -d "${TMPDIR_EXTRACT}"

    txt_count=0
    while IFS= read -r -d '' txt_file; do
        # Security: only copy regular .txt files, skip symlinks
        if [[ -f "${txt_file}" ]] && [[ ! -L "${txt_file}" ]]; then
            cp "${txt_file}" "${MAPS_DEST}/"
            txt_count=$((txt_count + 1))
        fi
    done < <(find "${TMPDIR_EXTRACT}" -name '*.txt' -type f -print0)

    if [[ "${txt_count}" -eq 0 ]]; then
        err "No .txt map files found in ${ZIP_FILE}"
        exit 1
    fi

    ok "Extracted ${txt_count} map files to ${MAPS_DEST}"
    exit 0
fi

# ─── Download from GitHub ────────────────────────────────────────────────────

if ! command -v git &>/dev/null; then
    err "git not found — install with: sudo apt install git"
    exit 1
fi

info "Downloading Good's maps from GitHub..."
info "  Repo: ${MAPS_REPO}"
info "  Commit: ${MAPS_COMMIT:0:12}"

TMPDIR_CLONE="$(mktemp -d)"
trap 'rm -rf "${TMPDIR_CLONE}"' EXIT

# Shallow clone to minimize download size
git clone --depth 1 --single-branch "${MAPS_REPO}.git" "${TMPDIR_CLONE}/goodurden-maps" 2>&1 | tail -2

# Verify the commit matches our pinned SHA (supply chain check)
actual_sha="$(git -C "${TMPDIR_CLONE}/goodurden-maps" rev-parse HEAD)"
if [[ "${actual_sha}" != "${MAPS_COMMIT}" ]]; then
    warn "Upstream has new commits (expected ${MAPS_COMMIT:0:12}, got ${actual_sha:0:12})"
    warn "Maps may have been updated. Proceeding with latest version."
fi

# Copy map files to EQ directory
map_source="${TMPDIR_CLONE}/goodurden-maps/${MAPS_DIR_IN_REPO}"
if [[ ! -d "${map_source}" ]]; then
    err "Map directory not found in repo: ${MAPS_DIR_IN_REPO}"
    exit 1
fi

mkdir -p "${MAPS_DEST}"

txt_count=0
while IFS= read -r -d '' txt_file; do
    # Security: only copy regular .txt files, skip symlinks
    if [[ -f "${txt_file}" ]] && [[ ! -L "${txt_file}" ]]; then
        cp "${txt_file}" "${MAPS_DEST}/"
        txt_count=$((txt_count + 1))
    fi
done < <(find "${map_source}" -name '*.txt' -type f -print0)

if [[ "${txt_count}" -eq 0 ]]; then
    err "No .txt map files found in ${map_source}"
    exit 1
fi

ok "Installed ${txt_count} map files to ${MAPS_DEST}"
ok "Good's maps installed successfully."
