#!/usr/bin/env bash
# Seed the Android methodology guide into PentAGI's pgvector knowledge store.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PG="${PENTAGI_PG_CONTAINER:-pgvector}"
DB="${PENTAGI_DB:-pentagidb}"
DBUSER="${PENTAGI_DB_USER:-postgres}"

GUIDE_FILE="$ROOT/knowledge/android_guide.txt" \
PENTAGI_ENV_FILE="${PENTAGI_ENV_FILE:-/opt/pentagi/.env}" \
python3 "$ROOT/knowledge/seed_guide.py"

docker cp /tmp/insert_guide.sql "$PG:/tmp/insert_guide.sql"
docker exec "$PG" psql -U "$DBUSER" -d "$DB" -f /tmp/insert_guide.sql
echo "Guide seeded."
