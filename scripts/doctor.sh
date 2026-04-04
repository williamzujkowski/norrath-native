#!/usr/bin/env bash
set -euo pipefail

# doctor.sh — Health check for norrath-native installation
# Validates that all components are properly configured and ready to launch.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config_reader.sh
source "${SCRIPT_DIR}/config_reader.sh"

PREFIX="${NN_PREFIX}"
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0
JSON_OUTPUT=0

# Results array for JSON output
RESULTS=()

# ─── Helpers ──────────────────────────────────────────────────────────────────

pass() {
    local id="$1" msg="$2"
    PASS_COUNT=$((PASS_COUNT + 1))
    RESULTS+=("{\"id\":\"${id}\",\"status\":\"pass\",\"message\":\"${msg}\"}")
    if [[ "${JSON_OUTPUT}" -eq 0 ]]; then
        printf '  \033[32m✓\033[0m %s\n' "${msg}"
    fi
}

warn() {
    local id="$1" msg="$2" fix="${3:-}"
    WARN_COUNT=$((WARN_COUNT + 1))
    RESULTS+=("{\"id\":\"${id}\",\"status\":\"warn\",\"message\":\"${msg}\",\"fix\":\"${fix}\"}")
    if [[ "${JSON_OUTPUT}" -eq 0 ]]; then
        printf '  \033[33m⚠\033[0m %s\n' "${msg}"
    fi
}

fail() {
    local id="$1" msg="$2" fix="${3:-}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    RESULTS+=("{\"id\":\"${id}\",\"status\":\"fail\",\"message\":\"${msg}\",\"fix\":\"${fix}\"}")
    if [[ "${JSON_OUTPUT}" -eq 0 ]]; then
        printf '  \033[31m✗\033[0m %s\n' "${msg}"
    fi
}

section() {
    if [[ "${JSON_OUTPUT}" -eq 0 ]]; then
        printf '\n\033[1m%s\033[0m\n' "$1"
    fi
}

# ─── Checks ───────────────────────────────────────────────────────────────────

check_system_deps() {
    section "System Dependencies"

    # Wine
    if command -v wine64 &>/dev/null; then
        local ver
        ver="$(wine64 --version 2>/dev/null | sed 's/wine-//')"
        pass "SYS_WINE" "wine64 ${ver}"
    elif command -v wine &>/dev/null; then
        local ver
        ver="$(wine --version 2>/dev/null | sed 's/wine-//')"
        pass "SYS_WINE" "wine ${ver}"
    else
        fail "SYS_WINE" "Wine not found" "run: make prereqs"
    fi

    # Vulkan
    if command -v vulkaninfo &>/dev/null; then
        local device
        device="$(vulkaninfo --summary 2>/dev/null | grep 'deviceName' | head -1 | sed 's/.*= //' || true)"
        if [[ -n "${device}" ]]; then
            pass "SYS_VULKAN" "Vulkan: ${device}"
        else
            warn "SYS_VULKAN" "vulkaninfo installed but no GPU detected" "check GPU drivers"
        fi
    else
        fail "SYS_VULKAN" "vulkaninfo not found" "run: make prereqs"
    fi

    # ntlm_auth (winbind)
    if command -v ntlm_auth &>/dev/null; then
        pass "SYS_NTLM" "ntlm_auth (winbind) available"
    else
        warn "SYS_NTLM" "ntlm_auth not found — install winbind to fix auth warnings" "sudo apt install winbind"
    fi

    # Node.js
    if command -v node &>/dev/null; then
        local node_ver
        node_ver="$(node --version 2>/dev/null)"
        pass "SYS_NODE" "Node.js ${node_ver}"
    else
        warn "SYS_NODE" "Node.js not found (needed for config-injector)" "run: make prereqs"
    fi
}

check_wine_prefix() {
    section "Wine Prefix"

    if [[ ! -d "${PREFIX}" ]]; then
        fail "PREFIX_EXISTS" "WINEPREFIX not found at ${PREFIX}" "run: make deploy"
        return
    fi
    pass "PREFIX_EXISTS" "WINEPREFIX exists: ${PREFIX}"

    # Architecture
    if grep -q '#arch=win64' "${PREFIX}/system.reg" 2>/dev/null; then
        pass "PREFIX_ARCH" "Architecture: win64"
    else
        fail "PREFIX_ARCH" "Prefix is not win64 architecture" "run: make deploy"
    fi

    # Virtual desktop
    if grep -q '"Default"=".*x.*"' "${PREFIX}/user.reg" 2>/dev/null; then
        local res
        res="$(grep '"Default"=".*x.*"' "${PREFIX}/user.reg" | head -1 | sed 's/.*"\(.*x.*\)"/\1/')"
        pass "PREFIX_VDESKTOP" "Virtual desktop: ${res}"
    else
        warn "PREFIX_VDESKTOP" "Virtual desktop not configured" "run: make deploy"
    fi
}

check_dxvk() {
    section "DXVK"

    local sys32="${PREFIX}/drive_c/windows/system32"
    local syswow="${PREFIX}/drive_c/windows/syswow64"

    if [[ -f "${sys32}/d3d11.dll" ]]; then
        pass "DXVK_SYS32_D3D11" "d3d11.dll in system32 (x64)"
    else
        fail "DXVK_SYS32_D3D11" "d3d11.dll missing from system32" "run: make deploy"
    fi

    if [[ -f "${syswow}/d3d11.dll" ]]; then
        pass "DXVK_WOW64_D3D11" "d3d11.dll in syswow64 (x32)"
    else
        fail "DXVK_WOW64_D3D11" "d3d11.dll missing from syswow64 (LaunchPad.exe is 32-bit)" "run: make deploy"
    fi

    if [[ -f "${sys32}/dxgi.dll" ]]; then
        pass "DXVK_SYS32_DXGI" "dxgi.dll in system32 (x64)"
    else
        fail "DXVK_SYS32_DXGI" "dxgi.dll missing from system32" "run: make deploy"
    fi

    if [[ -f "${syswow}/dxgi.dll" ]]; then
        pass "DXVK_WOW64_DXGI" "dxgi.dll in syswow64 (x32)"
    else
        fail "DXVK_WOW64_DXGI" "dxgi.dll missing from syswow64 (LaunchPad.exe is 32-bit)" "run: make deploy"
    fi

    # Check DLL overrides in registry
    if grep -q '"d3d11"="native"' "${PREFIX}/user.reg" 2>/dev/null; then
        pass "DXVK_OVERRIDE_D3D11" "DLL override: d3d11=native"
    else
        warn "DXVK_OVERRIDE_D3D11" "d3d11 DLL override not set" "run: make deploy"
    fi

    if grep -q '"dxgi"="native"' "${PREFIX}/user.reg" 2>/dev/null; then
        pass "DXVK_OVERRIDE_DXGI" "DLL override: dxgi=native"
    else
        warn "DXVK_OVERRIDE_DXGI" "dxgi DLL override not set" "run: make deploy"
    fi
}

check_everquest() {
    section "EverQuest"

    local eq_dir="${PREFIX}/drive_c/EverQuest"

    if [[ ! -d "${eq_dir}" ]]; then
        fail "EQ_DIR" "EverQuest not installed" "run: make deploy"
        return
    fi
    pass "EQ_DIR" "EQ directory: ${eq_dir}"

    if [[ -f "${eq_dir}/LaunchPad.exe" ]]; then
        local arch
        arch="$(file "${eq_dir}/LaunchPad.exe" 2>/dev/null | grep -o 'PE32[+]*' || echo 'unknown')"
        pass "EQ_LAUNCHER" "LaunchPad.exe (${arch})"
    else
        fail "EQ_LAUNCHER" "LaunchPad.exe not found" "run: make deploy"
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
            pass "EQ_INI" "eqclient.ini configured with managed settings"
        else
            warn "EQ_INI" "eqclient.ini exists but missing managed settings" "run: make configure"
        fi
    else
        warn "EQ_INI" "eqclient.ini not yet created (will be generated on first config inject)" "run: make configure"
    fi

    # Check patch status — eqgame.exe is the main game binary
    if [[ -f "${eq_dir}/eqgame.exe" ]]; then
        local eq_size
        eq_size="$(du -sh "${eq_dir}" 2>/dev/null | cut -f1)"
        pass "EQ_PATCHED" "Game patched (${eq_size} on disk)"
    else
        warn "EQ_PATCHED" "Game not yet patched" "run make launch, log in, and let the patcher finish"
    fi

    # Check for Remember Me token
    if command -v sqlite3 &>/dev/null && [[ -f "${eq_dir}/LaunchPad.libs/LaunchPad.Cache/Cookies" ]]; then
        # shellcheck disable=SC2016
        local token_count
        token_count="$(sqlite3 "${eq_dir}/LaunchPad.libs/LaunchPad.Cache/Cookies" \
            "SELECT count(*) FROM cookies WHERE name='lp-token';" 2>/dev/null || echo "0")"
        if [[ "${token_count}" -gt 0 ]]; then
            pass "EQ_REMEMBER_ME" "Remember Me enabled (auto-login active)"
        else
            warn "EQ_REMEMBER_ME" "Remember Me not set" "check the box on next login"
        fi
    fi
}

check_state() {
    section "Deploy State"

    local state_file="${HOME}/.local/share/norrath-native/state.json"

    if [[ ! -f "${state_file}" ]]; then
        warn "STATE_FILE" "No deploy state recorded" "run: make deploy"
        return
    fi

    # Extract fields with portable grep+sed (no jq dependency)
    local deployed_at wine_version dxvk_version
    deployed_at="$(grep -o '"deployed_at"[^,}]*' "${state_file}" | sed 's/.*": *"\(.*\)"/\1/')"
    wine_version="$(grep -o '"wine_version"[^,}]*' "${state_file}" | sed 's/.*": *"\(.*\)"/\1/')"
    dxvk_version="$(grep -o '"dxvk_version"[^,}]*' "${state_file}" | sed 's/.*": *"\(.*\)"/\1/')"

    pass "STATE_DEPLOYED_AT" "Deployed at: ${deployed_at}"
    pass "STATE_WINE_VERSION" "Wine version: ${wine_version}"
    pass "STATE_DXVK_VERSION" "DXVK version: ${dxvk_version}"
}

check_logs() {
    section "Logs"

    local log_dir="${HOME}/.local/share/norrath-native"
    if [[ -d "${log_dir}" ]]; then
        local count
        count="$(find "${log_dir}" -name '*.log' -type f 2>/dev/null | wc -l)"
        pass "LOG_DIR" "Log directory: ${log_dir} (${count} log files)"

        # Show last deploy time
        if [[ -f "${log_dir}/deploy.log" ]]; then
            local last
            last="$(tail -1 "${log_dir}/deploy.log" 2>/dev/null | grep -oP '^\[\K[^\]]+' || echo 'unknown')"
            pass "LOG_LAST_DEPLOY" "Last deploy: ${last}"
        fi
    else
        warn "LOG_DIR" "No log directory yet (created on first deploy)" "run: make deploy"
    fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Run a health check on the norrath-native installation.

Options:
  --prefix PATH   Override WINEPREFIX to check (default from config: ${PREFIX})
  --json          Output results as JSON (suppresses ANSI output)
  -h, --help      Show this help message
EOF
    exit 0
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --prefix)
                if [[ $# -lt 2 ]]; then
                    printf 'ERROR: --prefix requires a value\n' >&2
                    exit 1
                fi
                PREFIX="$2"
                shift 2
                ;;
            --json)
                JSON_OUTPUT=1
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                printf 'ERROR: Unknown option: %s\n' "$1" >&2
                usage
                ;;
        esac
    done

    if [[ "${JSON_OUTPUT}" -eq 0 ]]; then
        printf '\n\033[1m=== Norrath-Native Health Check ===\033[0m\n'
        printf 'Prefix: %s\n' "${PREFIX}"
    fi

    check_system_deps
    check_wine_prefix
    check_dxvk
    check_everquest
    check_state
    check_logs

    if [[ "${JSON_OUTPUT}" -eq 1 ]]; then
        # Build JSON array of results
        local joined
        joined="$(printf '%s,' "${RESULTS[@]}")"
        joined="${joined%,}"  # strip trailing comma
        printf '{\n'
        printf '  "passed": %d,\n' "${PASS_COUNT}"
        printf '  "warnings": %d,\n' "${WARN_COUNT}"
        printf '  "failed": %d,\n' "${FAIL_COUNT}"
        printf '  "checks": [%s]\n' "${joined}"
        printf '}\n'
    else
        # Summary
        printf '\n\033[1mSummary:\033[0m '
        printf '\033[32m%d passed\033[0m, ' "${PASS_COUNT}"
        printf '\033[33m%d warnings\033[0m, ' "${WARN_COUNT}"
        printf '\033[31m%d failed\033[0m\n\n' "${FAIL_COUNT}"

        if [[ "${FAIL_COUNT}" -gt 0 ]]; then
            printf 'Run \033[36mmake deploy\033[0m to fix failed checks.\n\n'
        elif [[ "${WARN_COUNT}" -gt 0 ]]; then
            printf 'System is functional but has warnings.\n\n'
        else
            printf 'All checks passed. Ready to launch!\n\n'
        fi
    fi

    if [[ "${FAIL_COUNT}" -gt 0 ]]; then
        exit 1
    fi
}

main "$@"
