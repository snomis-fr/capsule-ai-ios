#!/usr/bin/env bash

cd "$(dirname "$0")/.."

set +e
OUTPUT=$(xcodebuild -scheme CapsuleAI -destination 'generic/platform=iOS' build 2>&1)
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -eq 0 ]; then
    echo "BUILD OK"
else
    echo "$OUTPUT" | grep -E "error:" || echo "$OUTPUT" | tail -20
fi

exit $EXIT_CODE
