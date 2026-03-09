#!/usr/bin/env bash
cd "$(dirname "$0")/.."

xcodebuild -project CapsuleAI.xcodeproj -scheme CapsuleAI -destination 'platform=iOS Simulator,id=400EB285-E002-458E-8AF1-FF9C2884E6AE' build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
exit ${PIPESTATUS[0]}
