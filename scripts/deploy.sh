#!/usr/bin/env bash
# End-to-end deploy of the Android-capable PentAGI worker environment.
#
#   GENYMOTION_API_TOKEN=... ./scripts/deploy.sh
#
# Assumes a working PentAGI docker-compose deployment already exists.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PENTAGI_DIR="${PENTAGI_DIR:-/opt/pentagi}"
IMAGE="${PENTAGI_ANDROID_IMAGE:-pentagi-android:latest}"

echo "== 1/5 build worker image =="
bash "$ROOT/scripts/build-image.sh"

echo "== 2/5 point PentAGI at the image =="
ENV_FILE="$PENTAGI_DIR/.env"
[ -f "$ENV_FILE" ] || { echo "ERROR: $ENV_FILE not found"; exit 1; }
if grep -q '^DOCKER_DEFAULT_IMAGE_FOR_PENTEST=' "$ENV_FILE"; then
  sed -i "s|^DOCKER_DEFAULT_IMAGE_FOR_PENTEST=.*|DOCKER_DEFAULT_IMAGE_FOR_PENTEST=$IMAGE|" "$ENV_FILE"
else
  echo "DOCKER_DEFAULT_IMAGE_FOR_PENTEST=$IMAGE" >> "$ENV_FILE"
fi
grep '^DOCKER_DEFAULT_IMAGE_FOR_PENTEST=' "$ENV_FILE"

echo "== 3/5 recreate pentagi =="
( cd "$PENTAGI_DIR" && docker compose up -d pentagi )

echo "== 4/5 apply prompts + flow template =="
bash "$ROOT/scripts/apply-prompts.sh"
bash "$ROOT/scripts/apply-flow-template.sh"

echo "== 5/5 seed knowledge guide =="
bash "$ROOT/scripts/seed-guide.sh"

echo
echo "Deploy complete. Start a NEW flow to pick up the prompts/guide."
echo "On the worker terminal the agent can now run: android-vm up ; android-frida"
