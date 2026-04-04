#!/usr/bin/env bash
set -euo pipefail

# doctor.sh — Health check for norrath-native installation
# Validates that all components are properly configured and ready to launch.

PREFIX="${HOME}/.wine-eq"
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

# ─── Helpers ──────────────────────────────────────────────────────────────────

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    printf '  \033[32m✓\033[0m %s\n' "$1"
}

warn() {
    WARN_COUNT=$((WARN_COUNT + 1))
    printf '  \033[33m⚠\033[0m %s\n' "$1"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf '  \033[31m✗\033[0m %s\n' "$1"
}

section() {
    printf '\n\033[1m%s\033[0m\n' "$1"
}

# ─── Checks ───────────────────────────────────────────────────────────────────

check_system_deps() {
    section "System Dependencies"

    # Wine
    if command -v wine64 &>/dev/null; then
        local ver
        ver="$(wine64 --version 2>/dev/null | sed 's/wine-//')"
        pass "wine64 ${ver}"
    elif command -v wine &>/dev/null; then
        local ver
        ver="$(wine --version 2>/dev/null | sed 's/wine-//')"
        pass "wine ${ver}"
    else
        fail "Wine not found (run: make prereqs)"
    fi

    # Vulkan
    if command -v vulkaninfo &>/dev/null; then
        local device
        device="$(vulkaninfo --summary 2>/dev/null | grep 'deviceName' | head -1 | sed 's/.*= //' || true)"
        if [[ -n "${device}" ]]; then
            pass "Vulkan: ${device}"
        else
            warn "vulkaninfo installed but no GPU detected"
        fi
    else
        fail "vulkaninfo not found (run: make prereqs)"
    fi

    # ntlm_auth (winbind)
    if command -v ntlm_auth &>/dev/null; then
        pass "ntlm_auth (winbind) available"
    else
        warn "ntlm_auth not found — install winbind to fix auth warnings"
    fi

    # Node.js
    if command -v node &>/dev/null; then
        local node_ver
        node_ver="$(node --version 2>/dev/null)"
        pass "Node.js ${node_ver}"
    else
        warn "Node.js not found (needed for config-injector)"
    fi
}

check_wine_prefix() {
    section "Wine Prefix"

    if [[ ! -d "${PREFIX}" ]]; then
        fail "WINEPREFIX not found at ${PREFIX} (run: make deploy)"
        return
    fi
    pass "WINEPREFIX exists: ${PREFIX}"

    # Architecture
    if grep -q '#arch=win64' "${PREFIX}/system.reg" 2>/dev/null; then
        pass "Architecture: win64"
    else
        fail "Prefix is not win64 architecture"
    fi

    # Virtual desktop
    if grep -q '"Default"=".*x.*"' "${PREFIX}/user.reg" 2>/dev/null; then
        local res
        res="$(grep '"Default"=".*x.*"' "${PREFIX}/user.reg" | head -1 | sed 's/.*"\(.*x.*\)"/\1/')"
        pass "Virtual desktop: ${res}"
    else
        warn "Virtual desktop not configured (run: make deploy)"
    fi
}

check_dxvk() {
    section "DXVK"

    local sys32="${PREFIX}/drive_c/windows/system32"
    local syswow="${PREFIX}/drive_c/windows/syswow64"

    for dll in d3d11.dll dxgi.dll; do
        if [[ -f "${sys32}/${dll}" ]]; then
            pass "${dll} in system32 (x64)"
        else
            fail "${dll} missing from system32"
        fi

        if [[ -f "${syswow}/${dll}" ]]; then
            pass "${dll} in syswow64 (x32)"
        else
            fail "${dll} missing from syswow64 (LaunchPad.exe is 32-bit)"
        fi
    done

    # Check DLL overrides in registry
    if grep -q '"d3d11"="native"' "${PREFIX}/user.reg" 2>/dev/null; then
        pass "DLL override: d3d11=native"
    else
        warn "d3d11 DLL override not set"
    fi

    if grep -q '"dxgi"="native"' "${PREFIX}/user.reg" 2>/dev/null; then
        pass "DLL override: dxgi=native"
    else
        warn "dxgi DLL override not set"
    fi
}

check_everquest() {
    section "EverQuest"

    local eq_dir="${PREFIX}/drive_c/EverQuest"

    if [[ ! -d "${eq_dir}" ]]; then
        fail "EverQuest not installed (run: make deploy)"
        return
    fi
    pass "EQ directory: ${eq_dir}"

    if [[ -f "${eq_dir}/LaunchPad.exe" ]]; then
        local arch
        arch="$(file "${eq_dir}/LaunchPad.exe" 2>/dev/null | grep -o 'PE32[+]*' || echo 'unknown')"
        pass "LaunchPad.exe (${arch})"
    else
        fail "LaunchPad.exe not found"
    fi

    # Check for eqclient.ini
    if [[ -f "${eq_dir}/eqclient.ini" ]]; then
        local managed_ok=true
        for key in WindowedMode UpdateInBackground MaxBGFPS; do
            if ! grep -q "^${key}=" "${eq_dir}/eqclient.ini" 2>/dev/null; then
                managed_ok=false
            fi
        done
        if [[ "${managed_ok}" == "true" ]]; then
            pass "eqclient.ini configured with managed settings"
        else
            warn "eqclient.ini exists but missing managed settings (run: make configure)"
        fi
    else
        warn "eqclient.ini not yet created (will be generated on first config inject)"
    fi
}

check_logs() {
    section "Logs"

    local log_dir="${HOME}/.local/share/norrath-native"
    if [[ -d "${log_dir}" ]]; then
        local count
        count="$(find "${log_dir}" -name '*.log' -type f 2>/dev/null | wc -l)"
        pass "Log directory: ${log_dir} (${count} log files)"

        # Show last deploy time
        if [[ -f "${log_dir}/deploy.log" ]]; then
            local last
            last="$(tail -1 "${log_dir}/deploy.log" 2>/dev/null | grep -oP '^\[\K[^\]]+' || echo 'unknown')"
            pass "Last deploy: ${last}"
        fi
    else
        warn "No log directory yet (created on first deploy)"
    fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
    if [[ "${1:-}" == "--prefix" ]] && [[ -n "${2:-}" ]]; then
        PREFIX="$2"
    fi

    printf '\n\033[1m=== Norrath-Native Health Check ===\033[0m\n'
    printf 'Prefix: %s\n' "${PREFIX}"

    check_system_deps
    check_wine_prefix
    check_dxvk
    check_everquest
    check_logs

    # Summary
    printf '\n\033[1mSummary:\033[0m '
    printf '\033[32m%d passed\033[0m, ' "${PASS_COUNT}"
    printf '\033[33m%d warnings\033[0m, ' "${WARN_COUNT}"
    printf '\033[31m%d failed\033[0m\n\n' "${FAIL_COUNT}"

    if [[ "${FAIL_COUNT}" -gt 0 ]]; then
        printf 'Run \033[36mmake deploy\033[0m to fix failed checks.\n\n'
        exit 1
    elif [[ "${WARN_COUNT}" -gt 0 ]]; then
        printf 'System is functional but has warnings.\n\n'
        exit 0
    else
        printf 'All checks passed. Ready to launch!\n\n'
        exit 0
    fi
}

main "$@"
