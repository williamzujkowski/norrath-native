#!/usr/bin/env bash
set -euo pipefail

# deploy_ui.sh — Deploy a complete UI layout template to characters
#
# Instead of incrementally mutating INI files (which EQ overwrites
# unpredictably), this deploys a known-good FULL template.
#
# Strategy: overwrite from template, not partial mutation.
# The template is a snapshot of a working UI INI with proper
# chat windows, filters, timestamps, and positions.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config_reader.sh
source "${SCRIPT_DIR}/config_reader.sh"

PREFIX="${NN_PREFIX}"
DRY_RUN=0
TEMPLATE="raid-4window"
CHARACTER=""

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [CHARACTER]

Deploy a complete UI layout template to a character.

This REPLACES the character's UI INI with a known-good template,
then injects the correct channel routing and color scheme.

Templates:
  raid-4window    4 chat windows: Social, Combat, Spam, Alerts (default)

Options:
  --template NAME   Template to deploy (default: raid-4window)
  --list            List available templates
  --prefix PATH     Override WINEPREFIX
  --dry-run         Preview without changes
  -h, --help        Show this help

Examples:
  $(basename "$0") Grenlan           # Deploy to Grenlan
  $(basename "$0") --list            # Show templates
  $(basename "$0") --dry-run Malware # Preview changes
EOF
    exit 0
}

list_templates() {
    nn_log "Available UI templates:"
    local template_dir="${SCRIPT_DIR}/../templates/ui"
    for tmpl in "${template_dir}"/*.ini; do
        local name
        name="$(basename "${tmpl}" .ini)"
        local windows
        windows="$(grep '^NumWindows=' "${tmpl}" 2>/dev/null | head -1 | cut -d= -f2)"
        local names
        names="$(grep '_Name=' "${tmpl}" | grep 'ChatWindow' | head -4 | sed 's/.*_Name=//' | tr '\n' ', ' | sed 's/,$//')"
        nn_log "  ${name}: ${windows} windows (${names})"
    done
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --template)
            if [[ $# -lt 2 ]]; then nn_log "ERROR: --template needs a value"; exit 1; fi
            TEMPLATE="$2"; shift 2 ;;
        --list) list_templates ;;
        --prefix)
            if [[ $# -lt 2 ]]; then nn_log "ERROR: --prefix needs a value"; exit 1; fi
            PREFIX="$2"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help) usage ;;
        -*) nn_log "ERROR: Unknown option: $1"; exit 1 ;;
        *) CHARACTER="$1"; shift ;;
    esac
done

# Find template
TEMPLATE_DIR="${SCRIPT_DIR}/../templates/ui"
TEMPLATE_FILE="${TEMPLATE_DIR}/${TEMPLATE}.ini"

if [[ ! -f "${TEMPLATE_FILE}" ]]; then
    nn_log "ERROR: Template not found: ${TEMPLATE_FILE}"
    list_templates
fi

EQ_DIR="${PREFIX}/drive_c/EverQuest"

if [[ ! -d "${EQ_DIR}" ]]; then
    nn_log "ERROR: EverQuest directory not found. Run: make deploy"
    exit 1
fi

# Find target UI files
if [[ -n "${CHARACTER}" ]]; then
    # Deploy to specific character
    targets=("${EQ_DIR}"/UI_"${CHARACTER}"_*.ini)
    if [[ ! -f "${targets[0]}" ]]; then
        nn_log "ERROR: No UI file found for character: ${CHARACTER}"
        nn_log "Available characters:"
        for f in "${EQ_DIR}"/UI_*_*.ini; do
            nn_log "  $(basename "${f}" | sed 's/UI_//;s/_[^_]*\.ini//')"
        done
        exit 1
    fi
else
    # Deploy to all characters
    targets=()
    while IFS= read -r -d '' f; do
        targets+=("${f}")
    done < <(find "${EQ_DIR}" -maxdepth 1 -name "UI_*_*.ini" -print0 2>/dev/null)

    if [[ ${#targets[@]} -eq 0 ]]; then
        nn_log "ERROR: No UI files found. Log in first."
        exit 1
    fi
fi

nn_log "Template: ${TEMPLATE} ($(grep '^NumWindows' "${TEMPLATE_FILE}" | head -1 | cut -d= -f2) windows)"
nn_log ""

for target in "${targets[@]}"; do
    local_name="$(basename "${target}")"

    if [[ "${DRY_RUN}" -eq 1 ]]; then
        nn_log "[DRY-RUN] Would deploy ${TEMPLATE} → ${local_name}"
        continue
    fi

    # Back up existing
    cp "${target}" "${target}.bak" 2>/dev/null || true

    # Deploy template (full overwrite)
    cp "${TEMPLATE_FILE}" "${target}"

    # Apply channel routing and timestamps via TypeScript
    cli_cmd layout:apply "${target}" > /dev/null 2>&1 || true

    # Apply color scheme
    cli_cmd colors:apply "${target}" > /dev/null 2>&1 || true

    nn_log "Deployed ${TEMPLATE} → ${local_name} (backup: ${local_name}.bak)"
done

nn_log ""
nn_log "Done. Log in and your UI will have the template layout."
nn_log "If something breaks: cp UI_*.ini.bak UI_*.ini"
