#!/usr/bin/env bash
set -euo pipefail

flutter test \
  -d "$ANDROID_DEVICE" \
  "$TEST_TARGET"

flutter test \
  -d "$ANDROID_DEVICE" \
  --dart-define="$BACKEND_DEFINE" \
  "$BACKEND_TEST_TARGET"
