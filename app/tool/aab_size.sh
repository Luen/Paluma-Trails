#!/usr/bin/env bash
# Check the Play download size of the arm64 APKs generated from a release AAB.
#
# Usage: tool/aab_size.sh --aab build/app/outputs/bundle/release/app-release.aab [--budget-mb 20]
set -euo pipefail

AAB=""
BUDGET_MB=20
BUNDLETOOL_VERSION="1.18.3"
WORK_DIR="${RUNNER_TEMP:-/tmp}/paluma-aab-size"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --aab)
      AAB="$2"
      shift 2
      ;;
    --budget-mb)
      BUDGET_MB="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$AAB" || ! -f "$AAB" ]]; then
  echo "Usage: $0 --aab <app-release.aab> [--budget-mb 20]" >&2
  exit 2
fi

mkdir -p "$WORK_DIR"
BUNDLETOOL="$WORK_DIR/bundletool-all-${BUNDLETOOL_VERSION}.jar"
if [[ ! -f "$BUNDLETOOL" ]]; then
  echo "Downloading bundletool ${BUNDLETOOL_VERSION}..."
  curl -fsSL -o "$BUNDLETOOL" \
    "https://github.com/google/bundletool/releases/download/${BUNDLETOOL_VERSION}/bundletool-all-${BUNDLETOOL_VERSION}.jar"
fi

# bundletool needs a signing key to generate split APKs. Use the standard
# Android debug key; the size does not depend on which key signs the splits.
KEYSTORE="$HOME/.android/debug.keystore"
if [[ ! -f "$KEYSTORE" ]]; then
  mkdir -p "$(dirname "$KEYSTORE")"
  keytool -genkeypair -keystore "$KEYSTORE" -storepass android \
    -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 \
    -validity 10000 -dname "CN=Android Debug,O=Android,C=US" >/dev/null
fi

APKS="$WORK_DIR/app.apks"
echo "Building split APKs from $(basename "$AAB")..."
java -jar "$BUNDLETOOL" build-apks \
  --bundle="$AAB" \
  --output="$APKS" \
  --mode=default \
  --ks="$KEYSTORE" \
  --ks-key-alias=androiddebugkey \
  --ks-pass=pass:android \
  --key-pass=pass:android >/dev/null

# A Pixel 8 class device: arm64, 420 dpi, API 34. Only the arm64 slice matters
# for the download budget; Play removes the other ABIs.
SPEC="$WORK_DIR/pixel8.json"
cat > "$SPEC" <<'EOF'
{"supportedAbis":["arm64-v8a"],"supportedLocales":["en-US"],"screenDensity":420,"sdkVersion":34}
EOF

CSV="$(java -jar "$BUNDLETOOL" get-size total --apks="$APKS" --device-spec="$SPEC")"
SIZE_BYTES="$(printf '%s\n' "$CSV" | tail -n 1 | awk -F, '{print $NF}' | tr -cd '0-9')"
if [[ -z "$SIZE_BYTES" ]]; then
  echo "Could not parse bundletool output:" >&2
  printf '%s\n' "$CSV" >&2
  exit 1
fi

BUDGET_BYTES=$((BUDGET_MB * 1024 * 1024))
SIZE_MB="$(awk -v bytes="$SIZE_BYTES" 'BEGIN { printf "%.1f", bytes / 1024 / 1024 }')"
echo "Pixel 8 (arm64-v8a) Play download: ${SIZE_MB} MB (budget ${BUDGET_MB} MB)"

if (( SIZE_BYTES > BUDGET_BYTES )); then
  echo "::error::The arm64 Play download is ${SIZE_MB} MB, over the ${BUDGET_MB} MB budget." >&2
  exit 1
fi
