#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Builds the Dreadful Hardened FOSS APK (work.dreadful.kryfo) inside the repro container.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== Kryfo Dreadful Android Build (work.dreadful.kryfo) ==="
echo "Working directory: $ROOT"

# Ensure gradle has suitable memory settings
GRADLE_DIR="${GRADLE_USER_HOME:-$HOME/.gradle}"
mkdir -p "$GRADLE_DIR"
cat > "$GRADLE_DIR/gradle.properties" <<'EOF'
org.gradle.jvmargs=-Xmx2560m -XX:MaxMetaspaceSize=1G -XX:ReservedCodeCacheSize=512m -XX:+HeapDumpOnOutOfMemoryError -Djava.net.preferIPv4Stack=true
kotlin.daemon.jvmargs=-Xmx1g
org.gradle.workers.max=2
EOF

# Add Google Maven Central mirror to avoid HTTP 429 (Too Many Requests)
echo "=== Configuring Maven Central mirror ==="
sed -i 's|mavenCentral()|maven { url = uri("https://maven-central.storage-download.googleapis.com/maven2/") }\n        mavenCentral()|' \
  "$ROOT/mobile/android/settings.gradle.kts" "$ROOT/mobile/android/build.gradle.kts"

# Ensure applicationId is work.dreadful.kryfo
sed -i 's|applicationId = "app.kryfo"|applicationId = "work.dreadful.kryfo"|' \
  "$ROOT/mobile/android/app/build.gradle.kts"

# Raise file limit for cgo / openssl builds
ulimit -n 65536 2>/dev/null || true

echo "=== 1. Flutter dependencies ==="
cd "$ROOT/mobile"
flutter pub get

# Check if native libraries are already compiled (e.g. restored from cache)
if [[ -f "$ROOT/mobile/android/app/src/main/jniLibs/arm64-v8a/libhalo.so" && \
      -f "$ROOT/mobile/android/app/src/main/jniLibs/arm64-v8a/libkryfo_signal.so" && \
      -f "$ROOT/mobile/android/app/src/main/jniLibs/arm64-v8a/libkryfo_translate.so" && \
      -f "$ROOT/mobile/android/app/src/main/jniLibs/arm64-v8a/libkryfo_voice.so" ]]; then
  echo "=== Native libraries found in jniLibs! Skipping native rebuild ==="
else
  echo "=== 2. Go Engine (libhalo.so) ==="
  cd "$ROOT/engine"
  HALO_FULL=1 bash build.sh

  echo "=== 3. Signal Shim (libkryfo_signal.so) ==="
  cd "$ROOT/mobile/native/kryfo_signal"
  bash build-android.sh

  echo "=== 4. Translation Library (libkryfo_translate.so) ==="
  cd "$ROOT/engine/translate/native"
  KT_JNI_LIBS_DIR="$ROOT/mobile/android/app/src/main/jniLibs" bash build.sh

  echo "=== 5. Voice Library (libkryfo_voice.so) ==="
  cd "$ROOT/engine/voice/native"
  KV_JNI_LIBS_DIR="$ROOT/mobile/android/app/src/main/jniLibs" bash build.sh
fi

echo "=== 6. Flutter Build (assembleFossRelease) ==="
cd "$ROOT/mobile"

success=0
for attempt in 1 2 3; do
  echo "Flutter build attempt $attempt..."
  if flutter build apk --release --flavor foss; then
    success=1
    break
  fi
  echo "Build attempt $attempt failed, waiting 15s before retry..."
  sleep 15
done

if [[ "$success" -ne 1 ]]; then
  echo "Error: Flutter build failed after 3 attempts" >&2
  exit 1
fi

APK="$ROOT/mobile/build/app/outputs/flutter-apk/app-foss-release.apk"
if [[ -f "$APK" ]]; then
  echo "=== BUILD FINISHED SUCCESSFULLY ==="
  ls -lh "$APK"
  sha256sum "$APK"
else
  echo "Error: Output APK not found at $APK" >&2
  exit 1
fi
