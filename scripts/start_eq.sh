#!/usr/bin/env bash
set -euo pipefail

# start_eq.sh — Launch one or more EverQuest instances under Wine
# Usage: start_eq.sh [--instances N] [--stagger-delay S] [--prefix PATH] [--eq-dir PATH] [--wayland]

readonly SCRIPT_NAME="start_eq.sh"
readonly LOG_DIR="${HOME}/.local/share/norrath-native"
readonly EQ_EXECUTABLE="Launchpad.exe"

INSTANCES=1
STAGGER_DELAY=5
PREFIX="${HOME}/.wine-eq"
EQ_DIR=""
USE_WAYLAND=0
PIDS=()

usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

Launch EverQuest instances under Wine with optional multi-boxing support.

Options:
  --instances N          Number of instances to launch (default: 1)
  --stagger-delay SECS   Delay between instance launches in seconds (default: 5)
  --prefix PATH          WINEPREFIX path (default: ~/.wine-eq)
  --eq-dir PATH          EverQuest install directory (default: auto-detect in prefix)
  --wayland              Use Wayland display backend instead of X11
  --help                 Show this help message

Environment:
  NORRATH_WAYLAND=1      Alternative way to enable Wayland backend

Examples:
  ${SCRIPT_NAME}
  ${SCRIPT_NAME} --instances 3 --stagger-delay 10
  ${SCRIPT_NAME} --wayland --prefix ~/my-wine --eq-dir ~/my-wine/drive_c/EverQuest
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
            --instances)
                INSTANCES="$2"
                shift 2
                ;;
            --stagger-delay)
                STAGGER_DELAY="$2"
                shift 2
                ;;
            --prefix)
                PREFIX="$2"
                shift 2
                ;;
            --eq-dir)
                EQ_DIR="$2"
                shift 2
                ;;
            --wayland)
                USE_WAYLAND=1
                shift
                ;;
            --help)
                usage
                ;;
            *)
                log "ERROR: Unknown option: $1"
                usage
                ;;
        esac
    done
}

validate_environment() {
    log "Validating environment..."

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
    log "Received shutdown signal, stopping instances..."

    local i
    for (( i=${#PIDS[@]}-1; i>=0; i-- )); do
        local pid="${PIDS[i]}"
        if kill -0 "${pid}" 2>/dev/null; then
            log "Sending SIGTERM to instance $((i+1)) (PID ${pid})..."
            kill "${pid}" 2>/dev/null || true
        fi
    done

    for (( i=${#PIDS[@]}-1; i>=0; i-- )); do
        local pid="${PIDS[i]}"
        if kill -0 "${pid}" 2>/dev/null; then
            log "Waiting for instance $((i+1)) (PID ${pid}) to exit..."
            wait "${pid}" 2>/dev/null || true
        fi
    done

    log "All instances stopped."
    exit 0
}

launch_instances() {
    log "Launching ${INSTANCES} instance(s) with ${STAGGER_DELAY}s stagger delay..."

    trap graceful_shutdown SIGINT SIGTERM

    local i
    for (( i=1; i<=INSTANCES; i++ )); do
        local instance_log="${LOG_DIR}/eq-instance-${i}.log"

        log "Starting instance ${i}/${INSTANCES}..."

        WINEPREFIX="${PREFIX}" wine64 "${EQ_DIR}/${EQ_EXECUTABLE}" --disable-gpu \
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
    wait
    log "=== ${SCRIPT_NAME} finished ==="
}

main "$@"
