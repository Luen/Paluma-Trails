#!/usr/bin/env bash
# Regenerate the launcher icons and splash screens, then fail if the committed
# outputs are stale. Run from anywhere; CI runs this after `flutter pub get`.
set -euo pipefail

cd "$(dirname "$0")/.."

dart run flutter_launcher_icons
dart run flutter_native_splash:create

# The comparison is against the index so the check is meaningful both in CI
# (clean checkout) and locally (after staging the generated output).
if ! git diff --exit-code -- android ios web; then
  echo
  echo "Generated icons or splash screens are out of date. Commit the output." >&2
  exit 1
fi
