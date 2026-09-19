#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Secure E-Voting Setup"

if ! command -v flutter >/dev/null 2>&1; then
  if [ -d "$ROOT/../flutter/bin" ]; then
    export PATH="$ROOT/../flutter/bin:$PATH"
  else
    echo "Flutter not found. Install from https://docs.flutter.dev/get-started/install"
    echo "Or clone: git clone --depth 1 -b stable https://github.com/flutter/flutter.git ../flutter"
    exit 1
  fi
fi

if [ ! -f android/app/build.gradle ]; then
  echo "==> Creating Flutter platform folders..."
  flutter create --org com.secureevoting .
fi

echo "==> Installing Flutter dependencies..."
flutter pub get

if command -v firebase >/dev/null 2>&1; then
  echo "==> Installing Cloud Functions dependencies..."
  (cd functions && npm install)
else
  echo "Firebase CLI not found. Install: npm install -g firebase-tools"
fi

echo ""
echo "Setup complete!"
echo ""
echo "Next steps:"
echo "  1. flutterfire configure"
echo "  2. firebase emulators:start"
echo "  3. flutter run"
