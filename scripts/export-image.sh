#!/usr/bin/env bash
# Export the worker image for offline transport, or push it to a registry.
#
#   ./scripts/export-image.sh save [out.tar.gz]
#   REGISTRY_IMAGE=ghcr.io/<user>/pentagi-android:latest ./scripts/export-image.sh push
set -euo pipefail
IMAGE="${PENTAGI_ANDROID_IMAGE:-pentagi-android:latest}"
MODE="${1:-save}"
OUT="${2:-pentagi-android.tar.gz}"

case "$MODE" in
  save)
    docker save "$IMAGE" | gzip -1 > "$OUT"
    echo "Saved $IMAGE -> $OUT ($(du -h "$OUT" | cut -f1))"
    echo "Load on another host with: gunzip -c $OUT | docker load"
    ;;
  push)
    : "${REGISTRY_IMAGE:?set REGISTRY_IMAGE, e.g. ghcr.io/<user>/pentagi-android:latest}"
    docker tag "$IMAGE" "$REGISTRY_IMAGE"
    docker push "$REGISTRY_IMAGE"
    echo "Pushed $REGISTRY_IMAGE"
    ;;
  *)
    echo "usage: $0 [save|push] [out.tar.gz]"; exit 1 ;;
esac
