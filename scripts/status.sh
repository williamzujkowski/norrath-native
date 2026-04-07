#!/usr/bin/env bash
set -euo pipefail

# status.sh — Diagnostic status dashboard for norrath-native
#
# Shows the current state of monitors, Wine, EQ windows, and tiling.
# Useful for diagnosing dock/undock, resolution, and focus issues.
#
# Usage: bash scripts/status.sh [--json]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config_reader.sh
source "${SCRIPT_DIR}/config_reader.sh"

PREFIX="${NN_PREFIX}"
JSON_MODE=0

if [[ "${1:-}" == "--json" ]]; then
    JSON_MODE=1
fi

if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    cat <<EOF
Usage: $(basename "$0") [--json]

Show diagnostic status of the norrath-native environment.

Options:
  --json    Output as JSON (machine-readable)
  -h, --help  Show this help
EOF
    exit 0
fi

# ─── Gather Data ──────────────────────────────────────────────────────────────

# Physical monitor
monitor_res="$(DISPLAY=:0 xrandr 2>/dev/null | grep ' connected primary' | grep -oP '\d+x\d+' | head -1 || true)"
if [[ -z "${monitor_res}" ]]; then
    monitor_res="$(DISPLAY=:0 xrandr 2>/dev/null | grep ' connected' | grep -oP '\d+x\d+' | head -1 || echo 'unknown')"
fi
monitor_name="$(DISPLAY=:0 xrandr 2>/dev/null | grep ' connected' | head -1 | cut -d' ' -f1 || echo 'unknown')"

# nn_get_screen_size result (what tiling uses)
tile_size="$(nn_get_screen_size 2>/dev/null | tr ' ' 'x' || echo 'unknown')"

# EQ windows
helper="${SCRIPT_DIR}/../helpers/wine_helper.exe"
eq_windows=0
window_info=""
if [[ -f "${helper}" ]]; then
    window_info="$(WINEPREFIX="${PREFIX}" DISPLAY=:0 wine "${helper}" find 2>/dev/null || true)"
    if [[ -n "${window_info}" ]]; then
        eq_windows="$(echo "${window_info}" | grep -c '|')"
    fi
fi

# Main character config
main_char="${NN_MAIN_CHARACTER:-not set}"

# Deploy state (versions)
deploy_info="$(cli_cmd status:versions 2>/dev/null || echo '{}')"
wine_ver="$(echo "${deploy_info}" | grep -o '"wine_version"[^,}]*' | cut -d'"' -f4 || echo 'unknown')"
dxvk_ver="$(echo "${deploy_info}" | grep -o '"dxvk_version"[^,}]*' | cut -d'"' -f4 || echo 'unknown')"
deployed_at="$(echo "${deploy_info}" | grep -o '"deployed_at"[^,}]*' | cut -d'"' -f4 || echo 'unknown')"
profile="$(echo "${deploy_info}" | grep -o '"config_profile"[^,}]*' | cut -d'"' -f4 || echo 'unknown')"

# EQ running
eq_running="false"
if nn_is_eq_running 2>/dev/null; then
    eq_running="true"
fi

# ─── Output ───────────────────────────────────────────────────────────────────

if [[ "${JSON_MODE}" -eq 1 ]]; then
    cat <<EOF
{
  "monitor": { "name": "${monitor_name}", "resolution": "${monitor_res}" },
  "tiling_size": "${tile_size}",
  "wine_version": "${wine_ver}",
  "dxvk_version": "${dxvk_ver}",
  "config_profile": "${profile}",
  "deployed_at": "${deployed_at}",
  "eq_running": ${eq_running},
  "eq_windows": ${eq_windows},
  "main_character": "${main_char}"
}
EOF
    exit 0
fi

# Human-readable output
printf '\n'
printf '  \033[1m%s\033[0m\n' "norrath-native status"
printf '  %s\n' "──────────────────────────────────"

# Monitor
printf '  %-22s %s (%s)\n' "Monitor:" "${monitor_res}" "${monitor_name}"
printf '  %-22s %s\n' "Tiling uses:" "${tile_size}"

printf '\n'
printf '  %-22s %s\n' "Wine version:" "${wine_ver}"
printf '  %-22s %s\n' "DXVK version:" "${dxvk_ver}"
printf '  %-22s %s\n' "Profile:" "${profile}"
printf '  %-22s %s\n' "Last deploy:" "${deployed_at}"

printf '\n'
printf '  %-22s %s\n' "EQ running:" "${eq_running}"
printf '  %-22s %s\n' "EQ windows:" "${eq_windows}"
printf '  %-22s %s\n' "Main character:" "${main_char}"

# Per-window details
if [[ "${eq_windows}" -gt 0 ]] && [[ -n "${window_info}" ]]; then
    printf '\n  %-6s %-18s %-14s %s\n' "Index" "HWND" "Position" "Size"
    printf '  %s\n' "──────────────────────────────────────────────"
    while IFS='|' read -r idx hwnd pos size _pid; do
        printf '  %-6s %-18s %-14s %s\n' "${idx}" "${hwnd}" "${pos}" "${size}"
    done <<< "${window_info}"
fi

printf '\n'
