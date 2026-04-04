#!/usr/bin/env bash
# shellcheck disable=SC2034  # Variables used via nameref
set -euo pipefail

# apply_colors.sh — Apply optimized chat color scheme for raid readability
#
# Designed for EverQuest raiding on Linux. Color philosophy:
#   Communication: each channel is instantly distinguishable
#   Your combat:   warm tones (yellow/gold)
#   Your healing:  cool tones (mint/blue)
#   Incoming:      alert colors (red/salmon)
#   Others:        dimmed gray-blue (reduces raid spam)
#   Alerts:        high-contrast red (death, low HP)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config_reader.sh
source "${SCRIPT_DIR}/config_reader.sh"

DRY_RUN=0
PREFIX="${NN_PREFIX}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Apply an optimized chat color scheme to eqclient.ini.

The scheme is designed for raid readability:
  - Tells: bright pink (unmissable)
  - Guild: bright green
  - Group: soft blue
  - Raid:  orange
  - Your damage: warm yellow/gold
  - Your healing: cool mint/blue
  - Others' combat: dimmed gray (reduces spam)
  - Death/Low HP: bright red alert

Options:
  --prefix PATH   Override WINEPREFIX
  --dry-run       Preview changes without writing
  -h, --help      Show this help
EOF
    exit 0
}

# Color scheme: "ID R G B" per line
# ID maps to User_N in [TextColors] section (1-indexed)
read_color_scheme() {
    cat << 'COLORS'
1 255 255 255
4 40 240 40
5 255 100 100
6 255 200 100
8 200 200 255
9 130 180 255
10 255 165 0
11 0 230 0
12 255 128 255
13 0 200 200
14 255 255 0
2 255 50 50
3 0 255 255
7 255 0 0
15 255 255 100
16 255 50 50
47 255 255 100
48 255 200 200
92 255 165 50
101 255 80 80
151 255 0 0
20 240 200 0
21 240 240 80
22 255 255 200
23 255 150 50
76 255 100 100
77 255 200 50
98 240 240 80
99 200 150 255
100 100 220 255
104 255 180 80
24 100 255 200
25 150 200 255
26 100 255 150
96 0 255 128
146 150 200 255
147 100 255 200
148 150 255 150
149 100 220 150
28 255 150 150
29 255 200 80
30 255 100 100
31 150 200 150
34 100 255 200
86 200 150 150
87 150 200 150
130 255 150 50
36 110 130 150
37 110 130 150
38 130 150 170
39 100 120 140
40 110 140 130
41 110 140 130
42 120 150 140
43 100 130 120
17 180 130 255
49 160 120 200
50 170 130 220
52 180 180 220
142 180 140 100
53 255 220 100
54 200 200 255
59 255 200 50
111 255 220 80
58 100 255 200
109 255 200 50
119 100 255 160
62 220 160 80
63 180 200 100
64 100 180 220
65 200 150 200
66 220 180 140
67 140 200 180
68 200 170 130
69 170 170 220
70 220 200 140
71 180 220 180
73 255 255 0
90 130 200 255
91 255 200 50
140 0 200 0
18 200 200 255
57 200 180 100
72 0 200 200
129 100 255 100
144 200 150 255
150 150 180 255
138 100 150 255
131 200 255 150
113 200 220 180
116 200 130 80
COLORS
}

apply_colors() {
    local ini_file="$1"
    local changed=0

    while read -r idx r g b; do
        for component in Red Green Blue; do
            local key="User_${idx}_${component}"
            local val
            case "${component}" in
                Red)   val="${r}" ;;
                Green) val="${g}" ;;
                Blue)  val="${b}" ;;
            esac

            if grep -q "^${key}=" "${ini_file}" 2>/dev/null; then
                local current
                current="$(grep "^${key}=" "${ini_file}" | head -1 | cut -d= -f2)"
                if [[ "${current}" != "${val}" ]]; then
                    if [[ "${DRY_RUN}" -eq 0 ]]; then
                        sed -i "s/^${key}=.*/${key}=${val}/" "${ini_file}"
                    fi
                    changed=$((changed + 1))
                fi
            fi
        done
    done < <(read_color_scheme)

    printf '%d' "${changed}"
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --prefix)
                if [[ $# -lt 2 ]]; then nn_log "ERROR: --prefix requires a value"; exit 1; fi
                PREFIX="$2"; shift 2 ;;
            --dry-run) DRY_RUN=1; shift ;;
            -h|--help) usage ;;
            *) nn_log "ERROR: Unknown option: $1"; exit 1 ;;
        esac
    done

    local ini_file="${PREFIX}/drive_c/EverQuest/eqclient.ini"

    if [[ ! -f "${ini_file}" ]]; then
        nn_log "ERROR: eqclient.ini not found at ${ini_file}"
        nn_log "Run 'make deploy' first."
        exit 1
    fi

    if [[ "${DRY_RUN}" -eq 1 ]]; then
        nn_log "Preview: optimized color scheme for ${ini_file}"
        nn_log ""
        nn_log "Key changes:"
        nn_log "  Tell:     white → bright pink (#ff80ff)"
        nn_log "  Guild:    red → bright green (#00e600)"
        nn_log "  Group:    blue → soft blue (#82b4ff)"
        nn_log "  Raid:     white → orange (#ffa500)"
        nn_log "  Shout:    dark green → salmon (#ff6464)"
        nn_log "  Others:   bright → dimmed gray (#6e8296)"
        nn_log "  Healing:  mixed → mint/blue family"
        nn_log "  Low HP:   dark red → BRIGHT RED (#ff0000)"
        nn_log ""
        local count
        count="$(apply_colors "${ini_file}")"
        nn_log "Would change ${count} color values."
    else
        nn_log "Applying optimized color scheme to ${ini_file}..."
        local count
        count="$(apply_colors "${ini_file}")"
        nn_log "Updated ${count} color values."
        nn_log "Reload UI in-game with /loadskin to see changes."
    fi
}

main "$@"
