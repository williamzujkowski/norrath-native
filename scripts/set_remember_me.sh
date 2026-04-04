#!/usr/bin/env bash
set -euo pipefail

# set_remember_me.sh — Check and display Remember Me status for the EQ launcher
#
# The "Remember Me" checkbox creates a server-issued lp-token cookie
# that expires in 1 year. This token cannot be generated locally —
# it must be obtained by checking the box during login.
#
# This script can:
#   - Show current Remember Me status
#   - Decrypt and display all launcher cookies (for debugging)
#   - Back up the session token for disaster recovery

PREFIX="${HOME}/.wine-eq"
CACHE_DIR="${PREFIX}/drive_c/EverQuest/LaunchPad.libs/LaunchPad.Cache"
COOKIES_DB="${CACHE_DIR}/Cookies"
C_EXE="/tmp/norrath-native-dpapi-decrypt.exe"
C_SOURCE="/tmp/norrath-native-dpapi-decrypt.c"

log() {
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    printf '[%s] %s\n' "${timestamp}" "$*"
}

build_dpapi_tool() {
    if [[ -f "${C_EXE}" ]]; then
        return 0
    fi

    if ! command -v x86_64-w64-mingw32-gcc &>/dev/null; then
        log "ERROR: gcc-mingw-w64 required. Install: sudo apt install gcc-mingw-w64"
        exit 1
    fi

    cat > "${C_SOURCE}" << 'CEOF'
#include <windows.h>
#include <wincrypt.h>
#include <stdio.h>
#include <stdlib.h>
int main(int argc, char *argv[]) {
    if (argc < 2) return 1;
    const char *hex = argv[1];
    int len = (int)strlen(hex) / 2;
    BYTE *data = (BYTE*)malloc(len);
    for (int i = 0; i < len; i++) sscanf(hex + 2*i, "%2hhx", &data[i]);
    DATA_BLOB in = { (DWORD)len, data };
    DATA_BLOB out = { 0, NULL };
    if (CryptUnprotectData(&in, NULL, NULL, NULL, NULL, 0, &out)) {
        fwrite(out.pbData, 1, out.cbData, stdout);
        LocalFree(out.pbData);
    }
    free(data);
    return 0;
}
CEOF
    x86_64-w64-mingw32-gcc -o "${C_EXE}" "${C_SOURCE}" -lcrypt32 2>/dev/null
}

main() {
    if [[ ! -f "${COOKIES_DB}" ]]; then
        log "ERROR: No cookies database. Log in to the launcher first."
        exit 1
    fi

    if ! command -v python3 &>/dev/null || ! python3 -c "import cryptography" &>/dev/null; then
        log "ERROR: python3 + cryptography required. Install: pip install cryptography"
        exit 1
    fi

    build_dpapi_tool

    python3 << PYEOF
import json, sqlite3, base64, subprocess, os
from pathlib import Path
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

prefix = Path("${PREFIX}")
cache = prefix / "drive_c/EverQuest/LaunchPad.libs/LaunchPad.Cache"
prefs = json.loads((cache / "LocalPrefs.json").read_text())

raw_key = base64.b64decode(prefs["os_crypt"]["encrypted_key"])
result = subprocess.run(
    ["wine", "${C_EXE}", raw_key[5:].hex()],
    capture_output=True,
    env={**os.environ, "WINEPREFIX": "${PREFIX}"}
)
aes_key = result.stdout
if len(aes_key) != 32:
    print("ERROR: Failed to decrypt AES key")
    exit(1)

aesgcm = AESGCM(aes_key)

db = sqlite3.connect(str(cache / "Cookies"))

# Check for lp-token (Remember Me)
token_row = db.execute(
    "SELECT encrypted_value, datetime((expires_utc/1000000)-11644473600, 'unixepoch') "
    "FROM cookies WHERE name='lp-token'"
).fetchone()

# Check username
user_row = db.execute(
    "SELECT encrypted_value FROM cookies WHERE name='lp-u'"
).fetchone()

username = "unknown"
if user_row and user_row[0][:3] == b"v10":
    try:
        username = aesgcm.decrypt(user_row[0][3:15], user_row[0][15:], None).decode()
    except:
        pass

print()
print("=== EverQuest Launcher Session Status ===")
print(f"  Account:     {username}")

if token_row:
    expires = token_row[1]
    print(f"  Remember Me: ENABLED")
    print(f"  Token expires: {expires}")
    print()
    print("  Auto-login is active. The launcher will skip the login screen")
    print("  on next launch. The token is valid for ~1 year.")
    print()
    print("  Back up with: make backup-session")
else:
    print(f"  Remember Me: NOT ENABLED")
    print()
    print("  To enable: check 'Remember me on this computer' when you next log in.")
    print("  The launcher will then auto-login for ~1 year.")

print()

# Show all cookies if --verbose
if "${1:-}" == "--verbose" or "${1:-}" == "-v":
    print("All cookies:")
    for name, enc in db.execute("SELECT name, encrypted_value FROM cookies ORDER BY name"):
        if enc[:3] == b"v10":
            try:
                val = aesgcm.decrypt(enc[3:15], enc[15:], None).decode()
                if len(val) > 60:
                    val = val[:57] + "..."
                print(f"  {name:35s} = {val}")
            except:
                print(f"  {name:35s} = [decrypt error]")

db.close()
PYEOF
}

main "$@"
