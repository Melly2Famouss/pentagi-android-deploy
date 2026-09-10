FROM vxcontrol/kali-linux:latest

ENV DEBIAN_FRONTEND=noninteractive
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_RECIPE_UUID=33f56572-f006-4f79-8d53-26d8887288f9
ENV ANDROID_INSTANCE_NAME=pentagi-android
ENV FRIDA_VERSION=17.18.0
ENV PATH=/opt/android-sdk/platform-tools:/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/build-tools/35.0.0:/opt/android-tools:/opt/frida:$PATH

# ---------- Android SDK: cmdline-tools + platform-tools + build-tools ----------
RUN set -eux; \
    mkdir -p /opt/android-sdk/cmdline-tools; \
    cd /tmp; \
    curl -fsSL -o cmdtools.zip https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip; \
    unzip -q cmdtools.zip -d /tmp/cmdtools; \
    mv /tmp/cmdtools/cmdline-tools /opt/android-sdk/cmdline-tools/latest; \
    rm -rf /tmp/cmdtools cmdtools.zip; \
    yes | /opt/android-sdk/cmdline-tools/latest/bin/sdkmanager --licenses >/dev/null 2>&1 || true; \
    /opt/android-sdk/cmdline-tools/latest/bin/sdkmanager --install "platform-tools" "build-tools;35.0.0" "platforms;android-35" >/dev/null; \
    /opt/android-sdk/platform-tools/adb version

# ---------- Frida server binaries for every Android ABI ----------
RUN set -eux; mkdir -p /opt/frida; cd /opt/frida; \
    for a in arm64 arm x86_64 x86; do \
      curl -fsSL -o fs.xz "https://github.com/frida/frida/releases/download/${FRIDA_VERSION}/frida-server-${FRIDA_VERSION}-android-${a}.xz"; \
      xz -d fs.xz; mv fs "frida-server-${a}"; chmod 755 "frida-server-${a}"; \
    done; ls -la /opt/frida

# ---------- Python tooling (core) ----------
RUN pip install --break-system-packages --no-cache-dir \
      "frida==${FRIDA_VERSION}" frida-tools \
      objection \
      gmsaas

# ---------- Python tooling (optional, best-effort) ----------
RUN (pip install --break-system-packages --no-cache-dir androguard apkid apkleaks quark-engine || true)

# ---------- Extra Android tooling (jars / scripts) ----------
RUN apt-get update && apt-get install -y --no-install-recommends apktool jadx scrcpy && rm -rf /var/lib/apt/lists/*
RUN set -eux; mkdir -p /opt/android-tools; cd /opt/android-tools; \
    curl -fsSL -o uber-apk-signer.jar https://github.com/patrickfav/uber-apk-signer/releases/download/v1.3.0/uber-apk-signer-1.3.0.jar; \
    curl -fsSL -o dex-tools.zip https://github.com/pxb1988/dex2jar/releases/download/v2.4/dex-tools-v2.4.zip; \
    unzip -q dex-tools.zip; rm -f dex-tools.zip; \
    chmod +x dex-tools-v2.4/*.sh; \
    ln -sf /opt/android-tools/dex-tools-v2.4/d2j-dex2jar.sh /usr/local/bin/d2j-dex2jar; \
    ln -sf /opt/android-tools/dex-tools-v2.4/d2j-apk-sign.sh /usr/local/bin/d2j-apk-sign

# ---------- Genymotion config, token, helpers, docs ----------
RUN mkdir -p /opt/android
COPY gm_token /etc/android/gm_token
COPY android-vm /usr/local/bin/android-vm
COPY android-frida /usr/local/bin/android-frida
COPY frida_java_hook.py /opt/android/frida_java_hook.py
COPY README-android.md /opt/android/README.md
RUN chmod 600 /etc/android/gm_token && \
    chmod 755 /usr/local/bin/android-vm /usr/local/bin/android-frida && \
    printf '%s\n' 'export PATH=/opt/android-sdk/platform-tools:/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/build-tools/35.0.0:/opt/android-tools:/opt/frida:$PATH' > /etc/profile.d/android.sh && \
    chmod 644 /etc/profile.d/android.sh && \
    gmsaas config set android-sdk-path /opt/android-sdk

# ---------- sanity check (non-fatal inventory) ----------
RUN for t in adb fastboot apksigner zipalign aapt aapt2 apktool jadx frida frida-ps objection gmsaas mitmproxy tcpdump nmap sqlmap; do \
      printf "%-12s %s\n" "$t" "$(command -v "$t" || echo MISSING)"; \
    done; \
    ls -la /opt/frida; \
    echo "ANDROID_IMAGE_BUILD_OK"
