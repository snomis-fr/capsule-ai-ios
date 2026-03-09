#!/usr/bin/env bash
# Build + lance les tests XCUITest automatiquement.
# Usage: ./scripts/verify-and-run.sh

set -e
cd "$(dirname "$0")/.."

DESTINATION="platform=iOS Simulator,name=iPhone 17"

echo "▶ Build + tests XCUITest..."
xcodebuild test \
  -scheme CapsuleAI \
  -destination "$DESTINATION" \
  -only-testing:CapsuleAIUITests \
  2>&1 | tee /tmp/capsule-test.log

if grep -q "TEST SUCCEEDED" /tmp/capsule-test.log; then
    echo ""
    echo "✓ Tous les tests ont réussi"
    exit 0
else
    echo ""
    echo "❌ Échec des tests - voir /tmp/capsule-test.log"
    exit 1
fi
