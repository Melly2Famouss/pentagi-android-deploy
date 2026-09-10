#!/usr/bin/env python3
"""Seed the Android methodology guide into PentAGI's pgvector knowledge store.

Config (env or CLI args):
  GUIDE_FILE           guide text file            (default: ./android_guide.txt)
  PENTAGI_ENV_FILE     PentAGI .env with EMBEDDING_KEY (default: /opt/pentagi/.env)
  EMBEDDING_KEY        overrides the key read from the env file
  EMBEDDING_MODEL      default: mistral-embed
  EMBEDDING_ENDPOINT   default: https://api.mistral.ai/v1/embeddings
  COLLECTION_ID        langchain_pg_collection.uuid (default set below)
  PENTAGI_USER_ID      default: 1
Writes an SQL file that the wrapper applies with psql inside the pgvector container.
"""
import json
import os
import sys
import urllib.request

GUIDE_FILE = os.environ.get("GUIDE_FILE", os.path.join(os.path.dirname(os.path.abspath(__file__)), "android_guide.txt"))
OUT_SQL = os.environ.get("OUT_SQL", "/tmp/insert_guide.sql")
ENV_FILE = os.environ.get("PENTAGI_ENV_FILE", "/opt/pentagi/.env")
COLLECTION = os.environ.get("COLLECTION_ID", "ddc7753f-90aa-4c65-a556-877b914f6677")
USER_ID = int(os.environ.get("PENTAGI_USER_ID", "1"))
QUESTION = os.environ.get(
    "GUIDE_QUESTION",
    "Android mobile application penetration testing with the Genymotion cloud VM: "
    "boot the VM, adb, Frida dynamic instrumentation, objection, SSL pinning bypass, "
    "traffic interception, and signed-in Gmail/Facebook accounts",
)
DESCRIPTION = os.environ.get(
    "GUIDE_DESCRIPTION",
    "Full mobile assessment workflow for the Genymotion Android 15 VM in this worker image",
)
GUIDE_TYPE = os.environ.get("GUIDE_TYPE", "pentest")
MODEL = os.environ.get("EMBEDDING_MODEL", "mistral-embed")
ENDPOINT = os.environ.get("EMBEDDING_ENDPOINT", "https://api.mistral.ai/v1/embeddings")


def read_env_key(path, name):
    with open(path) as f:
        for line in f:
            if line.startswith(name + "="):
                return line.split("=", 1)[1].strip()
    raise SystemExit(f"{name} not found in {path}")


def embed(text, key):
    body = json.dumps({"model": MODEL, "input": [text]}).encode()
    req = urllib.request.Request(ENDPOINT, data=body, method="POST")
    req.add_header("Authorization", "Bearer " + key)
    req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.load(resp)["data"][0]["embedding"]


def main():
    content = open(GUIDE_FILE).read().strip()
    key = os.environ.get("EMBEDDING_KEY") or read_env_key(ENV_FILE, "EMBEDDING_KEY")
    vec = embed(content[:8192], key)
    vec_literal = "[" + ",".join(repr(float(x)) for x in vec) + "]"
    meta = {
        "doc_type": "guide",
        "user_id": USER_ID,
        "question": QUESTION,
        "description": DESCRIPTION,
        "guide_type": GUIDE_TYPE,
        "part_size": len(content),
        "total_size": len(content),
        "manual": True,
    }
    sql = (
        "INSERT INTO langchain_pg_embedding (uuid, collection_id, embedding, document, cmetadata)\n"
        "SELECT gen_random_uuid(), '{col}', '{vec}'::vector, $doc${doc}$doc$, $meta${meta}$meta$::json\n"
        "WHERE NOT EXISTS (\n"
        "  SELECT 1 FROM langchain_pg_embedding\n"
        "  WHERE collection_id = '{col}' AND cmetadata->>'question' = $q${q}$q$\n"
        ");\n"
    ).format(col=COLLECTION, vec=vec_literal, doc=content, meta=json.dumps(meta), q=QUESTION)
    with open(OUT_SQL, "w") as f:
        f.write(sql)
    print(f"embedding_dim={len(vec)} content_bytes={len(content)} sql={OUT_SQL}")


if __name__ == "__main__":
    main()
