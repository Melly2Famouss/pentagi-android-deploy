#!/usr/bin/env bash
# Build the pentagi-android worker image (adb, gmsaas, frida, apktool, jadx, ...).
#
# Requires a Genymotion Cloud API token in $GENYMOTION_API_TOKEN
# (or in ./android-image/gm_token, which is git-ignored).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMG_DIR="$ROOT/android-image"
IMAGE="${PENTAGI_ANDROID_IMAGE:-pentagi-android:latest}"

cd "$IMG_DIR"
if [ ! -s gm_token ]; then
  if [ -n "${GENYMOTION_API_TOKEN:-}" ]; then
    printf '%s' "$GENYMOTION_API_TOKEN" > gm_token
    trap 'rm -f gm_token' EXIT
  else
    echo "ERROR: provide GENYMOTION_API_TOKEN or android-image/gm_token" >&2
    exit 1
  fi
fi

echo "Building $IMAGE ..."
docker build -t "$IMAGE" .
echo "Done: $IMAGE"
