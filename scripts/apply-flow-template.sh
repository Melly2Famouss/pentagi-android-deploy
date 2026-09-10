#!/usr/bin/env bash
# Create the "Android mobile app assessment (Genymotion + Frida)" flow template.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PG="${PENTAGI_PG_CONTAINER:-pgvector}"
DB="${PENTAGI_DB:-pentagidb}"
DBUSER="${PENTAGI_DB_USER:-postgres}"
USER_ID="${PENTAGI_USER_ID:-1}"
TITLE="Android mobile app assessment (Genymotion + Frida)"

TPL_FILE="$ROOT/pentagi/flow-template.txt" TITLE="$TITLE" USER_ID="$USER_ID" \
python3 - <<'PY' > /tmp/flow_template.sql
import os
text = open(os.environ["TPL_FILE"]).read().strip()
title = os.environ["TITLE"]
uid = os.environ["USER_ID"]
print(
    "INSERT INTO flow_templates (user_id, title, text) "
    f"SELECT {uid}, $t${title}$t$, $x${text}$x$ "
    f"WHERE NOT EXISTS (SELECT 1 FROM flow_templates WHERE user_id={uid} AND title=$t${title}$t$);"
)
PY

docker cp /tmp/flow_template.sql "$PG:/tmp/flow_template.sql"
docker exec "$PG" psql -U "$DBUSER" -d "$DB" -f /tmp/flow_template.sql
echo "Flow template ensured."
