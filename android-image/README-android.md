# Android Pentest Environment (PentAGI worker image)

This container is pre-loaded with a full Android/mobile assessment toolkit and a
pre-wired Genymotion Cloud (SaaS) Android VM.

## The Android VM

| Property        | Value |
|-----------------|-------|
| Provider        | Genymotion Cloud SaaS |
| Recipe name     | `xenavm` |
| Recipe UUID     | `33f56572-f006-4f79-8d53-26d8887288f9` |
| Instance name   | `pentagi-android` |
| OS / arch       | Android 15 (API 35), `arm64-v8a` |
| RAM / CPU       | 8192 MB / 8 vCPU |
| ADB             | tunnel via `gmsaas` (serial is `localhost:<port>`) |
| Credentials     | API token baked at `/etc/android/gm_token` (root-only) |

### Boot / connect

```bash
android-vm up        # boot (or reuse) the VM + establish the ADB tunnel + adb root
android-vm status    # adb devices + gmsaas instances
android-vm apps      # list installed 3rd-party apps
android-vm adb ...   # run any adb command
android-vm shell ... # run a device shell command
android-vm down      # stop the VM (stops billing)
```

`android-vm up` is idempotent: it reuses an already-ONLINE instance named
`pentagi-android` (or any ONLINE instance booted from the same recipe) and only
starts a new one if none is running. Always run `android-vm down` when finished
— a running instance consumes credits.

### Apps already installed on the device

Third-party apps:

- `com.google.android.gm` — **Gmail, signed in as `melly2famouss@gmail.com`**
- `com.facebook.katana` — **Facebook, signed in (account `Facebook`)**
- `com.xparty.androidapp` — Xena
- `com.google.android.safetycore`, `com.google.android.contactkeys`, `com.google.android.verifier`

Signed-in accounts (usable for sign-up / login flows):

- Google: `melly2famouss@gmail.com`
- Facebook: `Facebook`

List them anytime with `android-vm apps` / `adb shell dumpsys account`.

## Frida

```bash
android-frida                 # push + start the matching frida-server, list processes
android-frida stop            # stop it
frida-ps -U                   # list processes
frida -U -f <package>         # spawn with the interactive REPL
```

### Frida 17 Java-bridge gotcha

Frida 17 removed the Java/ObjC bridges from the core agent. The `frida` CLI REPL
loads them automatically, but **custom Python scripts must load the bridge**.
Use the bundled helper:

```bash
frida_java_hook.py --attach com.xparty.androidapp --hook-textview
frida_java_hook.py --spawn com.xparty.androidapp --code 'Java.perform(() => send(Java.vm.version))'
frida_java_hook.py --attach com.xparty.androidapp --file myscript.js
```

`frida_java_hook.py` injects `frida_tools/bridges/java.js` and defines `Java`
before running your script.

## Tool inventory

- **ADB / SDK**: `adb`, `fastboot`, `sdkmanager`, `avdmanager`, `aapt`, `aapt2`,
  `apksigner`, `zipalign` (SDK at `/opt/android-sdk`)
- **Frida**: `frida`, `frida-ps`, `frida-trace`, `frida-discover`, `objection`;
  server binaries for `arm64/arm/x86_64/x86` in `/opt/frida`
- **Static analysis**: `apktool`, `jadx`, `jadx-gui`, `dex2jar` (`d2j-dex2jar`),
  `androguard`, `apkid`, `apkleaks`, `quark-engine`, `uber-apk-signer.jar`
- **Traffic / net**: `mitmproxy`, `tcpdump`, `nmap`, `bettercap`
- **Reverse / native**: `radare2`, `rizin`, `ghidra` (if present in base), `gdb`
- **Genymotion**: `gmsaas` (configured, SDK path set)

## Common workflows

```bash
# Install an APK
adb install -r app.apk

# Pull an installed APK (split-aware)
adb shell pm path com.target.app
adb pull /data/app/.../base.apk

# Decode / rebuild
apktool d app.apk -o app_src
apktool b app_src -o app_patched.apk
uber-apk-signer -a app_patched.apk

# Launch an app and find its pid
adb shell monkey -p com.target.app -c android.intent.category.LAUNCHER 1
adb shell pidof com.target.app

# UI automation
adb shell input tap X Y
adb shell input text 'hello'
adb shell uiautomator dump /sdcard/ui.xml && adb pull /sdcard/ui.xml

# Frida Java hook example (Frida 17 aware)
frida_java_hook.py --attach com.target.app --file hook.js
```

## Notes

- The worker container runs as `root` with `SYS_PTRACE` and `NET_ADMIN`.
- One Genymotion instance is shared by name; avoid starting a second one.
- The device is rooted with `adb root` (the image ships as unrooted Genymotion
  Android 15 and `android-vm up`/`android-frida` call `adb root` for you).
