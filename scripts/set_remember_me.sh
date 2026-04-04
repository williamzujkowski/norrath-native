#!/usr/bin/env bash
set -euo pipefail

# set_remember_me.sh — Enable "Remember me" in the EQ launcher
#
# This modifies the launcher's cookies database to enable auto-login.
# Requires: sqlite3, python3, cryptography (pip)
#
# The launcher stores credentials in Chrome v10 encrypted cookies.
# This script decrypts the options cookie, sets the remember flag,
# and re-encrypts it.

PREFIX="${HOME}/.wine-eq"
CACHE_DIR="${PREFIX}/drive_c/EverQuest/LaunchPad.libs/LaunchPad.Cache"
COOKIES_DB="${CACHE_DIR}/Cookies"
C_SOURCE="/tmp/norrath-native-dpapi-decrypt.c"
C_EXE="/tmp/norrath-native-dpapi-decrypt.exe"
E_SOURCE="/tmp/norrath-native-dpapi-encrypt.c"
E_EXE="/tmp/norrath-native-dpapi-encrypt.exe"

log() {
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    printf '[%s] %s\n' "${timestamp}" "$*"
}

check_prerequisites() {
    local missing=()
    for cmd in sqlite3 python3 wine; do
        if ! command -v "${cmd}" &>/dev/null; then
            missing+=("${cmd}")
        fi
    done

    if ! python3 -c "import cryptography" &>/dev/null; then
        missing+=("python3-cryptography (pip install cryptography)")
    fi

    if ! command -v x86_64-w64-mingw32-gcc &>/dev/null; then
        missing+=("gcc-mingw-w64 (sudo apt install gcc-mingw-w64)")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        log "ERROR: Missing prerequisites: ${missing[*]}"
        exit 1
    fi

    if [[ ! -f "${COOKIES_DB}" ]]; then
        log "ERROR: Cookies database not found. Log in to the launcher first."
        exit 1
    fi
}

build_dpapi_tools() {
    # Build decrypt tool if not already built
    if [[ ! -f "${C_EXE}" ]]; then
        log "Building DPAPI decrypt tool..."
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
    fi

    # Build encrypt tool if not already built
    if [[ ! -f "${E_EXE}" ]]; then
        log "Building DPAPI encrypt tool..."
        cat > "${E_SOURCE}" << 'CEOF'
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
    if (CryptProtectData(&in, NULL, NULL, NULL, NULL, 0, &out)) {
        fwrite(out.pbData, 1, out.cbData, stdout);
        LocalFree(out.pbData);
    }
    free(data);
    return 0;
}
CEOF
        x86_64-w64-mingw32-gcc -o "${E_EXE}" "${E_SOURCE}" -lcrypt32 2>/dev/null
    fi
}

main() {
    log "=== EverQuest Remember Me Configuration ==="

    check_prerequisites
    build_dpapi_tools

    log "Reading current cookie state..."

    # Use Python to decrypt, modify, and re-encrypt
    python3 << PYEOF
import json, sqlite3, base64, subprocess, os, sys
from pathlib import Path
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

prefix = Path("${PREFIX}")
cache = prefix / "drive_c/EverQuest/LaunchPad.libs/LaunchPad.Cache"
prefs = json.loads((cache / "LocalPrefs.json").read_text())

# Get AES key by decrypting DPAPI blob via Wine
raw_key = base64.b64decode(prefs["os_crypt"]["encrypted_key"])
dpapi_blob = raw_key[5:]  # strip "DPAPI" prefix

result = subprocess.run(
    ["wine", "${C_EXE}", dpapi_blob.hex()],
    capture_output=True,
    env={**os.environ, "WINEPREFIX": "${PREFIX}"}
)
aes_key = result.stdout
if len(aes_key) != 32:
    print(f"ERROR: Failed to decrypt AES key (got {len(aes_key)} bytes)")
    sys.exit(1)

aesgcm = AESGCM(aes_key)

def decrypt_cookie(enc):
    if enc[:3] == b"v10":
        return aesgcm.decrypt(enc[3:15], enc[15:], None).decode()
    return enc.decode()

def encrypt_cookie(plaintext):
    import secrets
    nonce = secrets.token_bytes(12)
    ct = aesgcm.encrypt(nonce, plaintext.encode(), None)
    return b"v10" + nonce + ct

db = sqlite3.connect(str(cache / "Cookies"))

# Read current state
rows = db.execute("SELECT name, encrypted_value FROM cookies").fetchall()
print("Current cookies:")
for name, enc in rows:
    try:
        val = decrypt_cookie(enc)
        print(f"  {name} = {val}")
    except:
        print(f"  {name} = [decrypt error]")

# Check if remember-me is already set
opts_row = db.execute("SELECT encrypted_value FROM cookies WHERE name='lp-options'").fetchone()
if opts_row:
    opts_val = decrypt_cookie(opts_row[0])
    print(f"\nCurrent lp-options: '{opts_val}'")

    if "rememberMe" in opts_val or len(opts_val) > 5:
        print("Remember Me appears to be already enabled.")
    else:
        # Set remember-me by updating the lp-options cookie
        # The launcher sets this to a JSON or query string with rememberMe flag
        # Based on Daybreak launcher analysis, the options cookie with remember
        # is typically: rememberMe=true or similar
        new_opts = "rememberMe=true"
        new_enc = encrypt_cookie(new_opts)
        db.execute(
            "UPDATE cookies SET encrypted_value=? WHERE name='lp-options'",
            (new_enc,)
        )
        db.commit()
        print(f"Updated lp-options to: '{new_opts}'")
        print("Remember Me enabled!")

db.close()
PYEOF

    log "Done. Next launch should auto-login."
}

main "$@"
