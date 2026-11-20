#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Builds the Android test APK (HALO_TEST_ID=1) inside the repro container.
# The resulting APK has applicationId "app.kryfo.bridgetest" and label
# "Kryfo test", installing cleanly alongside the official Kryfo app.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== Kryfo Android Test Build (HALO_TEST_ID=1) ==="
echo "Working directory: $ROOT"

# Ensure gradle has suitable memory settings
GRADLE_DIR="${GRADLE_USER_HOME:-$HOME/.gradle}"
mkdir -p "$GRADLE_DIR"
cat > "$GRADLE_DIR/gradle.properties" <<'EOF'
org.gradle.jvmargs=-Xmx2560m -XX:MaxMetaspaceSize=1G -XX:ReservedCodeCacheSize=512m -XX:+HeapDumpOnOutOfMemoryError -Djava.net.preferIPv4Stack=true
kotlin.daemon.jvmargs=-Xmx1g
org.gradle.workers.max=2
EOF

# Raise file limit for cgo / openssl builds
ulimit -n 65536 2>/dev/null || true

echo "=== 1. Flutter dependencies ==="
cd "$ROOT/mobile"
flutter pub get

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

echo "=== 6. Flutter Test APK (assembleFossDebug) ==="
cd "$ROOT/mobile"
export HALO_TEST_ID=1
flutter build apk --debug --flavor foss

APK="$ROOT/mobile/build/app/outputs/flutter-apk/app-foss-debug.apk"
if [[ -f "$APK" ]]; then
  echo "=== BUILD FINISHED SUCCESSFULLY ==="
  ls -lh "$APK"
  sha256sum "$APK"
else
  echo "Error: Output APK not found at $APK" >&2
  exit 1
fi
