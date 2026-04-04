#!/usr/bin/env bash
set -euo pipefail

# generate-docs.sh — Auto-generate documentation from source
#
# Generates:
#   docs/api/           — TypeDoc API reference (from TypeScript)
#   docs/commands.md    — Command reference (from --help output)
#   docs/checks.md      — Doctor check reference (from doctor --json)
#
# Usage: bash scripts/generate-docs.sh [--check]
#   --check   Verify docs are up to date (CI mode, exits non-zero on drift)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/.."
DOCS_DIR="${REPO_ROOT}/docs"
CHECK_MODE=0

if [[ "${1:-}" == "--check" ]]; then
    CHECK_MODE=1
fi

generate_typedoc() {
    nn_log "Generating TypeDoc API reference..."
    cd "${REPO_ROOT}"
    npx typedoc 2>&1 | tail -3
}

generate_command_reference() {
    nn_log "Generating command reference..."

    local output="${DOCS_DIR}/commands.md"
    mkdir -p "${DOCS_DIR}"

    {
        echo "# Command Reference"
        echo ""
        echo "*Auto-generated from script --help output. Do not edit manually.*"
        echo ""
        echo "## Makefile Targets"
        echo ""
        echo '```'
        make -C "${REPO_ROOT}" help 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g'
        echo '```'
        echo ""

        for script in "${REPO_ROOT}"/scripts/*.sh; do
            local name
            name="$(basename "${script}" .sh)"

            # Skip config_reader (sourced, not executed)
            if [[ "${name}" == "config_reader" ]]; then
                continue
            fi

            echo "## ${name}"
            echo ""
            echo '```'
            bash "${script}" --help 2>&1 || true
            echo '```'
            echo ""
        done
    } > "${output}"

    nn_log "  Written: ${output}"
}

generate_checks_reference() {
    nn_log "Generating doctor checks reference..."

    local output="${DOCS_DIR}/checks.md"
    mkdir -p "${DOCS_DIR}"

    {
        echo "# Doctor Checks Reference"
        echo ""
        echo "*Auto-generated from doctor --json output. Do not edit manually.*"
        echo ""
        echo "| ID | Description | Status |"
        echo "|---|---|---|"

        # Run doctor in JSON mode (may fail if no prefix exists, that's ok)
        local json
        json="$(bash "${REPO_ROOT}/scripts/doctor.sh" --json 2>/dev/null || echo '{"checks":[]}')"

        printf '%s' "${json}" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for check in data.get('checks', []):
        cid = check.get('id', '?')
        msg = check.get('message', '?')
        status = check.get('status', '?')
        print(f'| \`{cid}\` | {msg} | {status} |')
except:
    print('| - | Doctor output unavailable | - |')
" 2>/dev/null || echo "| - | Doctor not available | - |"

    } > "${output}"

    nn_log "  Written: ${output}"
}

check_drift() {
    nn_log "Checking for documentation drift..."
    cd "${REPO_ROOT}"

    local drift=0

    # Check TypeDoc
    npx typedoc 2>/dev/null
    if ! git diff --quiet docs/api/ 2>/dev/null; then
        nn_log "ERROR: TypeDoc output has drifted"
        drift=1
    fi

    # Check command reference
    generate_command_reference
    if ! git diff --quiet docs/commands.md 2>/dev/null; then
        nn_log "ERROR: Command reference has drifted"
        drift=1
    fi

    if [[ "${drift}" -eq 1 ]]; then
        nn_log "Run 'bash scripts/generate-docs.sh' and commit the changes"
        exit 1
    fi

    nn_log "All documentation is up to date"
}

main() {
    if [[ "${CHECK_MODE}" -eq 1 ]]; then
        check_drift
    else
        generate_typedoc
        generate_command_reference
        generate_checks_reference
        nn_log "Documentation generation complete"
    fi
}

main
