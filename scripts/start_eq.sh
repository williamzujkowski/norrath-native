#!/usr/bin/env bash
set -euo pipefail

# start_eq.sh — Launch one or more EverQuest instances under Wine
# Usage: start_eq.sh [--instances N] [--stagger-delay S] [--prefix PATH] [--eq-dir PATH] [--wayland]

readonly SCRIPT_NAME="start_eq.sh"
readonly LOG_DIR="${HOME}/.local/share/norrath-native"
readonly EQ_EXECUTABLE="LaunchPad.exe"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source config reader for defaults
# shellcheck source=config_reader.sh
source "${SCRIPT_DIR}/config_reader.sh"

INSTANCES="${NN_INSTANCES}"
STAGGER_DELAY="${NN_STAGGER_DELAY}"
PREFIX="${NN_PREFIX}"
EQ_DIR=""
USE_WAYLAND=0
DRY_RUN=0
[[ "${NN_DISPLAY}" == "wayland" ]] && USE_WAYLAND=1
WINE_CMD=""
PIDS=()

usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

Launch EverQuest instances under Wine with optional multi-boxing support.

Options:
  --multi                Use multibox_instances from config (default: 3)
  --instances N          Override instance count
  --stagger-delay SECS   Delay between instance launches (default: 5)
  --prefix PATH          WINEPREFIX path (default: ~/.wine-eq)
  --eq-dir PATH          EverQuest install directory (default: auto-detect)
  --wayland              Use Wayland display backend instead of X11
  --dry-run              Print what would be launched without starting Wine
  -h, --help             Show this help message

Environment:
  NORRATH_WAYLAND=1      Alternative way to enable Wayland backend

Examples:
  ${SCRIPT_NAME}                    # Launch 1 instance (raid focus)
  ${SCRIPT_NAME} --multi            # Launch multibox instances from config
  ${SCRIPT_NAME} --instances 4      # Launch exactly 4 instances
EOF
    exit 0
}

log() {
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    printf '[%s] %s\n' "${timestamp}" "$*"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --multi)
                INSTANCES="${NN_MULTIBOX_INSTANCES}"
                shift
                ;;
            --instances)
                if [[ $# -lt 2 ]]; then
                    log "ERROR: --instances requires a value"
                    exit 1
                fi
                INSTANCES="$2"
                shift 2
                ;;
            --stagger-delay)
                if [[ $# -lt 2 ]]; then
                    log "ERROR: --stagger-delay requires a value"
                    exit 1
                fi
                STAGGER_DELAY="$2"
                shift 2
                ;;
            --prefix)
                if [[ $# -lt 2 ]]; then
                    log "ERROR: --prefix requires a value"
                    exit 1
                fi
                PREFIX="$2"
                shift 2
                ;;
            --eq-dir)
                if [[ $# -lt 2 ]]; then
                    log "ERROR: --eq-dir requires a value"
                    exit 1
                fi
                EQ_DIR="$2"
                shift 2
                ;;
            --wayland)
                USE_WAYLAND=1
                shift
                ;;
            --dry-run)
                DRY_RUN=1
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                log "ERROR: Unknown option: $1"
                usage
                ;;
        esac
    done
}

detect_wine() {
    if command -v wine64 &>/dev/null; then
        WINE_CMD="wine64"
    elif command -v wine &>/dev/null; then
        WINE_CMD="wine"
    else
        log "ERROR: Wine not found. Run: make prereqs"
        exit 1
    fi
    log "Wine command: ${WINE_CMD}"
}

validate_environment() {
    log "Validating environment..."
    detect_wine

    if [[ ! -d "${PREFIX}" ]]; then
        log "ERROR: WINEPREFIX does not exist: ${PREFIX}"
        log "Run deploy_eq_env.sh first to create it."
        exit 1
    fi

    if [[ -z "${EQ_DIR}" ]]; then
        EQ_DIR="$(autodetect_eq_dir)"
    fi

    if [[ ! -d "${EQ_DIR}" ]]; then
        log "ERROR: EverQuest directory not found: ${EQ_DIR}"
        log "Specify it with --eq-dir or install EQ into the prefix."
        exit 1
    fi

    if [[ ! -f "${EQ_DIR}/${EQ_EXECUTABLE}" ]]; then
        log "ERROR: ${EQ_EXECUTABLE} not found in ${EQ_DIR}"
        exit 1
    fi

    log "WINEPREFIX: ${PREFIX}"
    log "EQ directory: ${EQ_DIR}"
}

autodetect_eq_dir() {
    local drive_c="${PREFIX}/drive_c"
    local candidates=(
        "${drive_c}/EverQuest"
        "${drive_c}/Program Files/EverQuest"
        "${drive_c}/Program Files (x86)/EverQuest"
        "${drive_c}/users/Public/Daybreak Game Company/Installed Games/EverQuest"
    )

    for candidate in "${candidates[@]}"; do
        if [[ -d "${candidate}" ]]; then
            printf '%s' "${candidate}"
            return 0
        fi
    done

    log "ERROR: Could not auto-detect EverQuest directory in ${drive_c}"
    log "Searched:"
    for candidate in "${candidates[@]}"; do
        log "  ${candidate}"
    done
    exit 1
}

configure_display_backend() {
    if [[ "${USE_WAYLAND}" -eq 1 ]] || [[ "${NORRATH_WAYLAND:-0}" == "1" ]]; then
        log "Configuring Wayland display backend..."
        export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
        export GDK_BACKEND=wayland
        export SDL_VIDEODRIVER=wayland
        export MOZ_ENABLE_WAYLAND=1
    else
        log "Using X11 display backend."
        export GDK_BACKEND="${GDK_BACKEND:-x11}"
    fi
}

graceful_shutdown() {
    log "Received shutdown signal, stopping all Wine processes..."

    # Use wineserver -k to cleanly shut down all Wine processes in the prefix
    WINEPREFIX="${PREFIX}" wineserver -k 2>/dev/null || true

    # Wait up to 10 seconds for wineserver to exit
    local deadline=$((SECONDS + 10))
    while WINEPREFIX="${PREFIX}" wineserver -k0 2>/dev/null && [[ ${SECONDS} -lt ${deadline} ]]; do
        sleep 0.5
    done

    # Force kill if still running
    if WINEPREFIX="${PREFIX}" wineserver -k0 2>/dev/null; then
        log "Wine processes did not exit in time, forcing..."
        WINEPREFIX="${PREFIX}" wineserver -k9 2>/dev/null || true
    fi

    # Reap background PIDs
    for pid in "${PIDS[@]}"; do
        wait "${pid}" 2>/dev/null || true
    done

    log "All instances stopped."
    exit 0
}

launch_instances() {
    if [[ "${DRY_RUN}" -eq 1 ]]; then
        local display_backend="x11"
        [[ "${USE_WAYLAND}" -eq 1 ]] && display_backend="wayland"
        printf '[DRY-RUN] Would launch with:\n'
        printf '  WINEPREFIX: %s\n' "${PREFIX}"
        printf '  Resolution: %s\n' "${NN_RESOLUTION}"
        printf '  Instances: %s\n' "${INSTANCES}"
        printf '  Stagger delay: %ss\n' "${STAGGER_DELAY}"
        printf '  Display: %s\n' "${display_backend}"
        printf '  EQ directory: %s\n' "${EQ_DIR}"
        printf '  Executable: %s --disable-gpu\n' "${EQ_EXECUTABLE}"
        exit 0
    fi

    log "Launching ${INSTANCES} instance(s) with ${STAGGER_DELAY}s stagger delay..."

    trap graceful_shutdown SIGINT SIGTERM

    local i
    for (( i=1; i<=INSTANCES; i++ )); do
        local instance_log="${LOG_DIR}/eq-instance-${i}.log"

        log "Starting instance ${i}/${INSTANCES}..."

        WINEPREFIX="${PREFIX}" "${WINE_CMD}" explorer "/desktop=Default,${NN_RESOLUTION}" \
            "${EQ_DIR}/${EQ_EXECUTABLE}" --disable-gpu \
            >> "${instance_log}" 2>&1 &

        local pid=$!
        PIDS+=("${pid}")
        log "Instance ${i} launched (PID ${pid}), logging to ${instance_log}"

        if [[ "${i}" -lt "${INSTANCES}" ]]; then
            log "Waiting ${STAGGER_DELAY}s before next instance..."
            sleep "${STAGGER_DELAY}"
        fi
    done

    log "All ${INSTANCES} instance(s) launched. PIDs: ${PIDS[*]}"
}

ensure_log_dir() {
    if [[ ! -d "${LOG_DIR}" ]]; then
        mkdir -p "${LOG_DIR}"
    fi
}

main() {
    parse_args "$@"
    ensure_log_dir
    log "=== ${SCRIPT_NAME} started ==="

    validate_environment
    configure_display_backend
    launch_instances

    log "Waiting for all instances to exit (Ctrl+C for graceful shutdown)..."

    # Wine explorer forks and the parent exits immediately.
    # Wait for wineserver to exit (it stays alive while any Wine processes run).
    WINEPREFIX="${PREFIX}" wineserver --wait 2>/dev/null || wait

    log "=== ${SCRIPT_NAME} finished ==="
}

main "$@"
