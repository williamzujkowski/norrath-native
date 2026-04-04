#!/usr/bin/env bash
set -euo pipefail

# login_helper.sh — Auto-fill EverQuest login credentials from pass
#
# IMPORTANT: This script must be run from a graphical terminal (not via
# automation) because Wine CEF requires real user-level input focus.
#
# Usage: Run this AFTER make launch, when the EQ login screen is visible.
# It gives you 5 seconds to click the username field, then types credentials.

readonly DELAY="${1:-5}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [DELAY_SECONDS]

Auto-fill EverQuest login credentials from the pass password store.

Prerequisites:
  - pass gaming/daybreak/username must exist
  - pass gaming/daybreak/password must exist
  - EQ launcher must be open with login screen visible

The script gives you ${DELAY} seconds to click the username field,
then types the credentials and presses Enter.

Options:
  DELAY_SECONDS   Time to click the username field (default: 5)
  --help          Show this help
EOF
    exit 0
}

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    usage
fi

# Verify credentials exist in pass
if ! pass gaming/daybreak/username &>/dev/null; then
    echo "ERROR: pass gaming/daybreak/username not found"
    echo "Store it with: echo 'your_username' | pass insert -e gaming/daybreak/username"
    exit 1
fi

if ! pass gaming/daybreak/password &>/dev/null; then
    echo "ERROR: pass gaming/daybreak/password not found"
    echo "Store it with: echo 'your_password' | pass insert -e gaming/daybreak/password"
    exit 1
fi

USERNAME=$(pass gaming/daybreak/username)
PASSWORD=$(pass gaming/daybreak/password)

echo ""
echo "=== EverQuest Login Helper ==="
echo ""
echo "1. Make sure the EQ launcher is open"
echo "2. Click the USERNAME field in the launcher"
echo "3. Come back here and press Enter"
echo ""
read -rp "Press Enter when ready (cursor should be in the username field)..."

echo ""
echo "Typing in ${DELAY} seconds — switch to the EQ launcher NOW!"
echo ""

for (( i=DELAY; i>0; i-- )); do
    printf "\r  %d..." "${i}"
    sleep 1
done
printf "\r  Typing...   \n"

# Type username via xdotool (the active window will be EQ if user switched)
if command -v xdotool &>/dev/null; then
    xdotool type --clearmodifiers --delay 50 "${USERNAME}"
    sleep 0.3
    xdotool key Tab
    sleep 0.3
    xdotool type --clearmodifiers --delay 50 "${PASSWORD}"
    sleep 0.3
    xdotool key Return
    echo ""
    echo "Credentials submitted! Check the EQ launcher."
elif command -v wtype &>/dev/null; then
    wtype "${USERNAME}"
    sleep 0.3
    wtype -k Tab
    sleep 0.3
    wtype "${PASSWORD}"
    sleep 0.3
    wtype -k Return
    echo ""
    echo "Credentials submitted! Check the EQ launcher."
else
    echo "ERROR: Neither xdotool nor wtype found."
    echo "Install with: sudo apt install xdotool"
    exit 1
fi
