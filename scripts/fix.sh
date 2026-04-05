#!/usr/bin/env bash
set -euo pipefail

# fix.sh — One command to make everything right.
#
# Detects the current state and fixes whatever needs fixing:
#   - Wine desktop resolution mismatch → updates registry
#   - EQ running → re-tiles windows (character-aware)
#   - EQ stopped → applies config, colors, layout, resolution
#   - Always shows status at the end
#
# Safe to run anytime, running or not, docked or undocked.
#
# Usage: bash scripts/fix.sh [--dry-run]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config_reader.sh
source "${SCRIPT_DIR}/config_reader.sh"

PREFIX="${NN_PREFIX}"
DRY_RUN=0

if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=1
fi

if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    cat <<EOF
Usage: $(basename "$0") [--dry-run]

One command to make everything right. Detects your current state
and fixes whatever needs fixing.

If EQ is running:
  1. Syncs Wine desktop to your current monitor
  2. Re-tiles windows with character identification
  3. Focuses main character window

If EQ is stopped:
  1. Syncs Wine desktop to your current monitor
  2. Applies optimized eqclient.ini settings
  3. Applies chat colors and layout
  4. Scales UI for current resolution

Options:
  --dry-run   Preview what would change
  -h, --help  Show this help
EOF
    exit 0
fi

# ─── Detect State ─────────────────────────────────────────────────────────────

monitor_res="$(DISPLAY=:0 xrandr 2>/dev/null | grep ' connected primary' | grep -oP '\d+x\d+' | head -1 || true)"
if [[ -z "${monitor_res}" ]]; then
    monitor_res="$(DISPLAY=:0 xrandr 2>/dev/null | grep ' connected' | grep -oP '\d+x\d+' | head -1 || echo '1920x1080')"
fi

wine_desktop="$(grep -oP '"Default"="\K[^"]+' "${PREFIX}/user.reg" 2>/dev/null || echo 'not set')"
eq_running="false"
if nn_is_eq_running 2>/dev/null; then
    eq_running="true"
fi

nn_log "=== norrath-native fix ==="
nn_log ""
nn_log "  Monitor:        ${monitor_res}"
nn_log "  Wine desktop:   ${wine_desktop}"
nn_log "  EQ running:     ${eq_running}"
nn_log "  Main character: ${NN_MAIN_CHARACTER:-not set}"
nn_log ""

# ─── Step 1: Sync Wine desktop ───────────────────────────────────────────────

changes=0

if [[ "${wine_desktop}" != "${monitor_res}" ]]; then
    nn_log "Step 1: Wine desktop ${wine_desktop} → ${monitor_res}"
    if [[ "${DRY_RUN}" -eq 0 ]]; then
        "${NN_WINE_CMD}" reg add \
            'HKEY_CURRENT_USER\Software\Wine\Explorer\Desktops' \
            /v Default /d "${monitor_res}" /f >/dev/null 2>&1
    else
        nn_log "  [DRY-RUN] Would update Wine desktop"
    fi
    changes=1
else
    nn_log "Step 1: Wine desktop OK (${wine_desktop})"
fi

# ─── Step 1b: Ensure WM decorations are disabled ─────────────────────────────
# Wine's virtual desktop inherits window manager decorations (resize grips,
# borders) which absorb clicks near edges — especially at the origin.
# Disabling decorations and WM control prevents this.

if ! grep -q '"Decorated"="N"' "${PREFIX}/user.reg" 2>/dev/null; then
    nn_log "Step 1b: Disabling Wine WM decorations (prevents edge click issues)"
    if [[ "${DRY_RUN}" -eq 0 ]]; then
        "${NN_WINE_CMD}" reg add \
            'HKEY_CURRENT_USER\Software\Wine\X11 Driver' \
            /v Decorated /d N /f >/dev/null 2>&1
        "${NN_WINE_CMD}" reg add \
            'HKEY_CURRENT_USER\Software\Wine\X11 Driver' \
            /v Managed /d N /f >/dev/null 2>&1
    else
        nn_log "  [DRY-RUN] Would disable WM decorations"
    fi
    changes=1
else
    nn_log "Step 1b: WM decorations OK (disabled)"
fi

# ─── Step 2: EQ-specific fixes ───────────────────────────────────────────────

if [[ "${eq_running}" == "true" ]]; then
    # EQ is running — re-tile windows
    local_eq_count="$(nn_find_eq_windows | wc -l)"

    if [[ "${local_eq_count}" -gt 0 ]]; then
        nn_log "Step 2: Re-tiling ${local_eq_count} EQ window(s)"
        if [[ "${DRY_RUN}" -eq 0 ]]; then
            bash "${SCRIPT_DIR}/smart_tile.sh" auto --prefix "${PREFIX}"
        else
            nn_log "  [DRY-RUN] Would re-tile via smart_tile.sh"
        fi
        changes=1
    else
        nn_log "Step 2: EQ running but no windows found (still loading?)"
    fi
else
    # EQ is stopped — apply full config
    nn_log "Step 2: Applying configuration (EQ not running)"
    if [[ "${DRY_RUN}" -eq 0 ]]; then
        bash "${SCRIPT_DIR}/resolution_manager.sh" apply --resolution "${monitor_res}" 2>/dev/null || true
        bash "${SCRIPT_DIR}/configure_eq.sh" 2>/dev/null || true
        bash "${SCRIPT_DIR}/apply_colors.sh" 2>/dev/null || true
        bash "${SCRIPT_DIR}/apply_layout.sh" 2>/dev/null || true
    else
        nn_log "  [DRY-RUN] Would apply: resolution, config, colors, layout"
    fi
    changes=1
fi

# ─── Done ─────────────────────────────────────────────────────────────────────

nn_log ""
if [[ "${changes}" -eq 0 ]]; then
    nn_log "Everything looks good. No changes needed."
else
    if [[ "${DRY_RUN}" -eq 1 ]]; then
        nn_log "Run without --dry-run to apply these changes."
    else
        nn_log "Done. All fixes applied."
    fi
fi
