#!/usr/bin/env bash
# Generate the Android upload keystore and key.properties for release builds.
#
# Both files are git-ignored. Back them up before uploading to Play: with Play
# App Signing a lost upload key can be reset, but automated releases stay
# blocked until Google approves the reset.
#
# Usage:
#   tool/create_upload_keystore.sh
#
# Environment:
#   KEYSTORE        keystore path (default: android/app/upload-keystore.jks)
#   PROPERTIES      key.properties path (default: android/key.properties)
#   STORE_PASSWORD  keystore password (prompted when unset)
#   KEY_PASSWORD    key password (defaults to the keystore password)
#   KEY_ALIAS       key alias (default: paluma-upload)
#   KEY_DNAME       certificate distinguished name (default below)
set -euo pipefail

# The keystore and key.properties contain private signing material.
umask 077

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEYSTORE="${KEYSTORE:-$APP_DIR/android/app/upload-keystore.jks}"
PROPERTIES="${PROPERTIES:-$APP_DIR/android/key.properties}"
KEY_ALIAS="${KEY_ALIAS:-paluma-upload}"
KEY_DNAME="${KEY_DNAME:-CN=Paluma Trails, OU=Mobile, O=Paluma Trails, L=Paluma, ST=Queensland, C=AU}"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

command -v keytool >/dev/null 2>&1 ||
  die 'keytool not found; install a JDK (Android Studio bundles one).'

if [[ -e "$KEYSTORE" || -e "$PROPERTIES" ]]; then
  die "refusing to overwrite $KEYSTORE or $PROPERTIES; move them aside first"
fi

read_secret() {
  local prompt=$1 value
  read -r -s -p "$prompt: " value
  echo >&2
  printf '%s' "$value"
}

STORE_PASSWORD="${STORE_PASSWORD:-}"
if [[ -z "$STORE_PASSWORD" ]]; then
  STORE_PASSWORD="$(read_secret 'Keystore password (at least 6 characters)')"
  confirmation="$(read_secret 'Repeat keystore password')"
  [[ "$STORE_PASSWORD" == "$confirmation" ]] || die 'passwords do not match'
fi
(( ${#STORE_PASSWORD} >= 6 )) ||
  die 'the keystore password must be at least 6 characters'

KEY_PASSWORD="${KEY_PASSWORD:-$STORE_PASSWORD}"
(( ${#KEY_PASSWORD} >= 6 )) ||
  die 'the key password must be at least 6 characters'

mkdir -p "$(dirname "$KEYSTORE")" "$(dirname "$PROPERTIES")"

keytool -genkeypair \
  -keystore "$KEYSTORE" \
  -alias "$KEY_ALIAS" \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -storepass "$STORE_PASSWORD" \
  -keypass "$KEY_PASSWORD" \
  -dname "$KEY_DNAME" \
  -noprompt

cat > "$PROPERTIES" <<EOF
storePassword=$STORE_PASSWORD
keyPassword=$KEY_PASSWORD
keyAlias=$KEY_ALIAS
storeFile=$KEYSTORE
EOF
chmod 600 "$KEYSTORE" "$PROPERTIES"

cat <<EOF

Created:
  $KEYSTORE
  $PROPERTIES

Back both up somewhere safe; the keystore is the upload key for every Play
release. Do not commit either file (both are git-ignored).

Set the GitHub secrets from the repository root:

  base64 < "$KEYSTORE" | tr -d '\\n' | gh secret set ANDROID_KEYSTORE_BASE64
  gh secret set ANDROID_KEYSTORE_PASSWORD   # paste the keystore password
  gh secret set ANDROID_KEY_ALIAS --body "$KEY_ALIAS"
  gh secret set ANDROID_KEY_PASSWORD        # paste the key password

Then follow docs/signing.md for Play App Signing, the first manual upload and
the production environment. This script does not set any secrets for you.
EOF
