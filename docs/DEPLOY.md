# Deployment guide

## Prerequisites

- A host with Docker + docker compose and an existing PentAGI deployment
  (`docker-compose.yml`, `.env`, containers `pentagi`, `pgvector`).
- A Genymotion Cloud API token (create one at <https://cloud.geny.io/api>).
- Disk: ~25 GB free for the worker image.
- Outbound internet from the host (Google Android SDK, GitHub releases, PyPI,
  Genymotion API/WS).

## 1. Build the worker image

```bash
GENYMOTION_API_TOKEN=xxxxxxxx ./scripts/build-image.sh
```

This builds `pentagi-android:latest` from `android-image/`. The token is written
to `android-image/gm_token` only for the duration of the build and removed after.

## 2. Point PentAGI at it

```bash
cd /opt/pentagi
cp -a .env .env.bak-$(date +%Y%m%d-%H%M%S)
sed -i 's|^DOCKER_DEFAULT_IMAGE_FOR_PENTEST=.*|DOCKER_DEFAULT_IMAGE_FOR_PENTEST=pentagi-android:latest|' .env
# if the key does not exist yet:
#   echo 'DOCKER_DEFAULT_IMAGE_FOR_PENTEST=pentagi-android:latest' >> .env
docker compose up -d pentagi
```

PentAGI's image chooser sends security/pentest tasks to
`DOCKER_DEFAULT_IMAGE_FOR_PENTEST`, so new flows get the Android image.

## 3. Apply the agent knowledge

```bash
./scripts/apply-prompts.sh          # 6 prompt overrides (Android sections)
./scripts/apply-flow-template.sh    # ready-to-use flow template
./scripts/seed-guide.sh             # vector-store guide (uses EMBEDDING_KEY)
```

`seed-guide.sh` calls the configured embedding provider (Mistral by default,
read from `PENTAGI_ENV_FILE`) and inserts the guide into
`langchain_pg_embedding`. Override with `EMBEDDING_KEY`, `EMBEDDING_ENDPOINT`,
`EMBEDDING_MODEL`, `COLLECTION_ID`, `PENTAGI_ENV_FILE`.

Or do steps 1-3 in one shot:

```bash
GENYMOTION_API_TOKEN=xxxxxxxx ./scripts/deploy.sh
```

## 4. Use it

Start a **new** flow (prompts/guide load at flow creation). Suggested task text is
in `pentagi/flow-template.txt` (also available in the UI as a flow template).

Inside the worker terminal:

```bash
android-vm up          # boot/reuse VM, adb root, connect
android-vm apps        # installed 3rd-party apps
android-frida          # push + start frida-server
frida-ps -U
frida -U -f com.xparty.androidapp
android-vm down        # stop the VM (stops billing)
```

The worker README is installed at `/opt/android/README.md` in the image.

## Transporting the image

```bash
./scripts/export-image.sh save pentagi-android.tar.gz   # then: gunzip -c ... | docker load
REGISTRY_IMAGE=ghcr.io/<user>/pentagi-android:latest ./scripts/export-image.sh push
```

GitHub repositories cannot store the 22 GB image; use a registry (GHCR supports
large images) or a tarball on shared storage.

## Updating the knowledge later

- Prompts: edit `pentagi/prompts/full/*.tmpl` (or `append/`) and re-run
  `scripts/apply-prompts.sh`.
- Guide: edit `knowledge/android_guide.txt` and re-run `scripts/seed-guide.sh`.
  The insert is idempotent on the guide `question` string.

## Troubleshooting

- **Agent ignores Android tools** — start a new flow; existing flows keep the
  prompts loaded when they were created.
- **`android-vm up` starts a second VM** — it reuses an ONLINE instance named
  `pentagi-android` or any ONLINE instance from the same recipe. Stop stray
  instances with `gmsaas instances list` / `android-vm down`.
- **VM auto-stops** — Genymotion org default timeout (often 120 min). Start with
  a longer `--max-run-duration` if needed.
- **`gmsaas` auth errors** — check `/etc/android/gm_token` in the container.
- **Image pull on container create** — `pullImage` skips pulling when the image
  exists locally, so a local-only tag is safe.
