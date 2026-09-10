# pentagi-android-deploy

Reproducible deployment of an **Android-capable PentAGI worker environment**:
a custom Kali-based Docker image pre-loaded with a full mobile pentest toolkit
and a pre-wired Genymotion Cloud Android VM, plus the PentAGI prompt/knowledge
customizations that make the agents use it.

Built and verified against **PentAGI 2.1.0-ea66530**.

## What this gives you

- `pentagi-android:latest` worker image (spawned by PentAGI for pentest flows) with:
  - Android SDK: `adb`, `fastboot`, `sdkmanager`, `aapt/aapt2`, `apksigner`, `zipalign`
  - Frida (`frida`, `frida-ps`, `objection`) + `frida-server` for arm64/arm/x86_64/x86
  - `apktool`, `jadx`, `dex2jar`, `androguard`, `apkid`, `apkleaks`, `quark`, `uber-apk-signer`
  - `gmsaas` (Genymotion CLI, pre-configured), `scrcpy`, `mitmproxy`, `tcpdump`, `nmap`
  - helper commands `android-vm` and `android-frida`, and a Frida-17 Java-bridge helper
- PentAGI agent prompts customized with Android/mobile knowledge for
  `primary_agent`, `generator`, `pentester`, `installer`, `coder`, `subtasks_generator`
- A vector-store **guide** so `search_guide` surfaces the Android methodology
- A ready-to-use **flow template**: "Android mobile app assessment (Genymotion + Frida)"

## Layout

```
android-image/        Dockerfile + helper scripts + worker README
pentagi/              docker-compose.yml, .env.example, prompt overrides
knowledge/            Android methodology guide + seeding script
scripts/              build / apply / deploy / export automation
docs/DEPLOY.md        detailed instructions
```

## Quick start

```bash
# 0. On a host with a working PentAGI docker-compose deployment
# 1. Provide your Genymotion Cloud API token and deploy
GENYMOTION_API_TOKEN=xxxxxxxx ./scripts/deploy.sh
```

Then start a **new** PentAGI flow. Inside the worker terminal the agent can run:

```bash
android-vm up        # boot/reuse the Android 15 (arm64) VM and connect adb
android-frida        # push + start frida-server, list processes
frida-ps -U
```

## Important notes

- **Secrets are not committed.** `android-image/gm_token`, `pentagi/.env`, tokens
  and keys are git-ignored. Provide them at deploy time.
- The **22 GB worker image is not stored in git** (GitHub file limits). It is
  rebuilt by `scripts/build-image.sh` from `vxcontrol/kali-linux`. For offline
  transport use `scripts/export-image.sh save`, or push to a registry with
  `scripts/export-image.sh push`.
- The Genymotion VM itself is a **cloud SaaS** instance (`xenavm` recipe,
  Android 15 arm64); nothing to host locally.
- Prompt overrides are captured as full bodies for the version above. If your
  PentAGI version differs, compare against `pentagi/prompts/append/` and merge
  the Android sections into your version's defaults.
- The Genymotion API token is baked into the worker image at build time
  (`/etc/android/gm_token`, root-only). Treat the image as sensitive.

See [docs/DEPLOY.md](docs/DEPLOY.md) for the full procedure.
