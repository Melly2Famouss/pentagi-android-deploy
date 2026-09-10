#!/usr/bin/env bash
# Apply the customized PentAGI agent prompts (Android knowledge) for a user.
#
# By default it installs the FULL prompt bodies captured from a known-good
# deployment (PentAGI 2.1.0-ea66530). If your PentAGI version differs, instead
# append the snippets in pentagi/prompts/append/ to the matching default
# templates, or review the full files against your version first.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PG="${PENTAGI_PG_CONTAINER:-pgvector}"
DB="${PENTAGI_DB:-pentagidb}"
DBUSER="${PENTAGI_DB_USER:-postgres}"
USER_ID="${PENTAGI_USER_ID:-1}"
SQL=/tmp/apply_prompts.sql
: > "$SQL"

i=0
for f in "$ROOT"/pentagi/prompts/full/*.tmpl; do
  t="$(basename "$f" .tmpl)"
  docker cp "$f" "$PG:/tmp/prompt_$i.tmpl"
  echo "\\set c$i \`cat /tmp/prompt_$i.tmpl\`" >> "$SQL"
  echo "INSERT INTO prompts (type,user_id,prompt) VALUES ('$t',$USER_ID,:'c$i') ON CONFLICT (type,user_id) DO UPDATE SET prompt=EXCLUDED.prompt;" >> "$SQL"
  i=$((i+1))
done

docker cp "$SQL" "$PG:/tmp/apply_prompts.sql"
docker exec "$PG" psql -U "$DBUSER" -d "$DB" -f /tmp/apply_prompts.sql
echo "Applied $i prompts for user_id=$USER_ID"
docker exec "$PG" psql -U "$DBUSER" -d "$DB" -c "select type, length(prompt) len, strpos(prompt,'android-vm up')>0 has_android from prompts where user_id=$USER_ID order by type;"
