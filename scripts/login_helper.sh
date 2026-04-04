#!/usr/bin/env bash
set -euo pipefail

# login_helper.sh — Auto-fill EverQuest login credentials from pass
#
# Wine CEF (Chromium) ignores synthetic X events (xdotool, xte). On Wayland
# desktops, wtype works because it uses the virtual-keyboard protocol.
# On X11, the clipboard fallback (xclip + Ctrl+V) is most reliable.
#
# Usage: Run this AFTER make launch, when the EQ login screen is visible.

DELAY="${1:-5}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [DELAY_SECONDS]

Auto-fill EverQuest login from the pass password store.

Prerequisites:
  - pass gaming/daybreak/username and password must exist
  - EQ launcher must be open with login screen visible

Steps:
  1. Run 'make launch' in one terminal
  2. Run 'make login' in another terminal
  3. Click the username field in the EQ launcher
  4. Press Enter in this terminal
  5. Switch to EQ launcher within ${DELAY} seconds

Options:
  DELAY_SECONDS   Seconds to switch to EQ (default: 5)
  --help          Show this help
EOF
    exit 0
}

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    usage
fi

# Verify credentials
for key in username password; do
    if ! pass "gaming/daybreak/${key}" &>/dev/null; then
        echo "ERROR: pass gaming/daybreak/${key} not found"
        exit 1
    fi
done

USERNAME=$(pass gaming/daybreak/username)
PASSWORD=$(pass gaming/daybreak/password)

# Detect best input method
detect_input_method() {
    local session_type="${XDG_SESSION_TYPE:-x11}"

    if [[ "${session_type}" == "wayland" ]] && command -v wtype &>/dev/null; then
        echo "wtype"
    elif command -v xdotool &>/dev/null && command -v xclip &>/dev/null; then
        echo "clipboard"
    elif command -v xdotool &>/dev/null; then
        echo "xdotool"
    else
        echo "none"
    fi
}

INPUT_METHOD=$(detect_input_method)

echo ""
echo "=== EverQuest Login Helper ==="
echo "Input method: ${INPUT_METHOD}"
echo ""
echo "Steps:"
echo "  1. Click the USERNAME field in the EQ launcher"
echo "  2. Come back here and press Enter"
echo "  3. Switch to the EQ window within ${DELAY} seconds"
echo ""
read -rp "Press Enter when ready..."
echo ""

for (( i=DELAY; i>0; i-- )); do
    printf "\r  Switch to EQ now... %d " "${i}"
    sleep 1
done
printf "\r  Typing credentials...    \n"

case "${INPUT_METHOD}" in
    wtype)
        # Wayland virtual keyboard protocol — works with CEF
        wtype -- "${USERNAME}"
        sleep 0.3
        wtype -k Tab
        sleep 0.3
        wtype -- "${PASSWORD}"
        sleep 0.3
        wtype -k Return
        ;;

    clipboard)
        # Clipboard paste — most reliable fallback for X11/XWayland
        # Copy username to clipboard, simulate Ctrl+V, Tab, repeat for password
        echo -n "${USERNAME}" | xclip -selection clipboard
        sleep 0.1
        xdotool key --clearmodifiers ctrl+v
        sleep 0.3
        xdotool key --clearmodifiers Tab
        sleep 0.3
        echo -n "${PASSWORD}" | xclip -selection clipboard
        sleep 0.1
        xdotool key --clearmodifiers ctrl+v
        sleep 0.3
        xdotool key --clearmodifiers Return
        # Clear clipboard for security
        echo -n "" | xclip -selection clipboard
        ;;

    xdotool)
        # Direct xdotool type — may not work with CEF on some setups
        xdotool type --clearmodifiers --delay 50 -- "${USERNAME}"
        sleep 0.3
        xdotool key Tab
        sleep 0.3
        xdotool type --clearmodifiers --delay 50 -- "${PASSWORD}"
        sleep 0.3
        xdotool key Return
        ;;

    none)
        echo "ERROR: No input injection tool found."
        echo "Install wtype (Wayland) or xdotool+xclip (X11):"
        echo "  sudo apt install wtype  # Wayland"
        echo "  sudo apt install xdotool xclip  # X11"
        exit 1
        ;;
esac

echo ""
echo "Credentials submitted. Check the EQ launcher."
echo ""
echo "If the fields are empty, try:"
echo "  1. Click the username field first"
echo "  2. Run: make login"
echo "  3. Switch to EQ faster (try: make login DELAY=3)"
