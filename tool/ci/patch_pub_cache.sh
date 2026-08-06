#!/usr/bin/env bash
# tool/ci/patch_pub_cache.sh
#
# Replicates the pub-cache Kotlin/AGP patches that used to live only in the
# retired Flutter build container (see docs/BUILD_SETUP.md) on a fresh CI runner.
#
# Legacy pub packages carry their own buildscript classpaths (Kotlin 2.2.0 +
# AGP 8.12.1) which conflict with this fork's pinned AGP 8.9.2 / Gradle 8.14.3.
# For each package below we rewrite android/build.gradle:
#   ext.kotlin_version = '2.2.0'        -> '2.2.21'
#   com.android.tools.build:gradle:X.Y.Z -> 8.9.2
#
# Idempotent: re-running is a no-op (patterns no longer match).
set -euo pipefail

CACHE="${PUB_CACHE:-$HOME/.pub-cache}/hosted/pub.dev"
PKGS=(
  camera_android_camerax
  image_picker_android
  package_info_plus
  shared_preferences_android
  url_launcher_android
  video_player_android
)

patched=0
skipped=0

for pkg in "${PKGS[@]}"; do
  d=$(ls -d "$CACHE"/"$pkg"-* 2>/dev/null | head -1 || true)
  if [ -z "$d" ]; then
    echo "SKIP $pkg (not in pub cache)"
    skipped=$((skipped + 1))
    continue
  fi
  f="$d/android/build.gradle"
  if [ ! -f "$f" ]; then
    echo "SKIP $pkg (no android/build.gradle at $f)"
    skipped=$((skipped + 1))
    continue
  fi
  sed -i -E \
    -e "s/(ext\.kotlin_version[[:space:]]*=[[:space:]]*['\"])2\.2\.0(['\"])/\12.2.21\2/g" \
    -e "s/(com\.android\.tools\.build:gradle:)[0-9.]+/\18.9.2/g" \
    "$f"
  echo "PATCHED $pkg -> $(grep -oE "kotlin_version = '[0-9.]+'|com.android.tools.build:gradle:[0-9.]+" "$f" | tr '\n' ' ')"
  patched=$((patched + 1))
done

echo "patch_pub_cache: $patched patched, $skipped skipped"
