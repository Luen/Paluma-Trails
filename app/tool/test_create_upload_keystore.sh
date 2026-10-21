#!/usr/bin/env bash
# Smoke-test the upload keystore helper without touching the real signing files.
set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="$TOOL_DIR/create_upload_keystore.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

perms() {
  stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"
}

generate() {
  local dir=$1
  mkdir -p "$dir"
  KEYSTORE="$dir/upload.jks" PROPERTIES="$dir/key.properties" \
    STORE_PASSWORD=testpass KEY_PASSWORD=testpass "$HELPER" >/dev/null
}

# A normal run creates both files with private permissions.
generate "$TMP/ok"
[[ -f "$TMP/ok/upload.jks" ]] || fail 'keystore was not created'
[[ -f "$TMP/ok/key.properties" ]] || fail 'key.properties was not created'
[[ "$(perms "$TMP/ok/upload.jks")" == 600 ]] || fail 'keystore is not mode 600'
[[ "$(perms "$TMP/ok/key.properties")" == 600 ]] ||
  fail 'key.properties is not mode 600'
grep -qx 'storePassword=testpass' "$TMP/ok/key.properties" ||
  fail 'store password missing from key.properties'
grep -qx 'keyAlias=paluma-upload' "$TMP/ok/key.properties" ||
  fail 'default alias missing from key.properties'
keytool -list -keystore "$TMP/ok/upload.jks" -storepass testpass >/dev/null ||
  fail 'keytool cannot read the generated keystore'

# Existing files are never overwritten.
if generate "$TMP/ok" 2>/dev/null; then
  fail 'the helper overwrote an existing keystore'
fi

# Passwords shorter than the keytool minimum are rejected before any file is
# created.
if KEYSTORE="$TMP/short/upload.jks" PROPERTIES="$TMP/short/key.properties" \
  STORE_PASSWORD=short KEY_PASSWORD=testpass "$HELPER" >/dev/null 2>&1; then
  fail 'a short password was accepted'
fi
[[ ! -e "$TMP/short/upload.jks" ]] || fail 'short password created a keystore'

# Interactive confirmation must match.
if printf 'password-one\npassword-two\n' |
  KEYSTORE="$TMP/mismatch/upload.jks" PROPERTIES="$TMP/mismatch/key.properties" \
    "$HELPER" >/dev/null 2>&1; then
  fail 'mismatched passwords were accepted'
fi
[[ ! -e "$TMP/mismatch/upload.jks" ]] || fail 'mismatch created a keystore'

printf 'create_upload_keystore.sh: all checks passed\n'
