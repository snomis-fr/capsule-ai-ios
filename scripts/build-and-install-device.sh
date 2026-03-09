#!/usr/bin/env bash
# Build et installe l'app sur l'iPhone connecté (STNOPM17).
# Branchez votre iPhone en USB, déverrouillez-le, et acceptez "Faire confiance".

set -e
cd "$(dirname "$0")/.."

# iPhone connecté (ajustez le nom si besoin)
DEVICE_NAME="STNOPM17"
DESTINATION="platform=iOS,name=$DEVICE_NAME"

echo "▶ Vérification de l'iPhone connecté..."
if ! xcrun xctrace list devices 2>/dev/null | grep -q "$DEVICE_NAME"; then
    echo "❌ iPhone '$DEVICE_NAME' non détecté."
    echo "   Branchez votre iPhone en USB, déverrouillez-le, et acceptez 'Faire confiance'."
    echo ""
    echo "   Appareils disponibles:"
    xcrun xctrace list devices 2>/dev/null | grep -E "iPhone|iPad" || true
    exit 1
fi
echo "✓ iPhone détecté"

echo "▶ Build pour appareil..."
xcodebuild -scheme CapsuleAI \
  -destination "$DESTINATION" \
  -allowProvisioningUpdates \
  -configuration Debug \
  build 2>&1 | tee /tmp/capsule-device-build.log

if ! grep -q "BUILD SUCCEEDED" /tmp/capsule-device-build.log; then
    echo "❌ Build échoué - voir /tmp/capsule-device-build.log"
    exit 1
fi
echo "✓ Build OK"

echo "▶ Recherche de l'app..."
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "CapsuleAI.app" -path "*/Debug-iphoneos/*" -mmin -5 2>/dev/null | head -1)
if [ -z "$APP_PATH" ]; then
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "CapsuleAI.app" -path "*/Debug-iphoneos/*" 2>/dev/null | head -1)
fi
if [ -z "$APP_PATH" ]; then
    echo "❌ CapsuleAI.app non trouvée (build iphoneos)"
    exit 1
fi
echo "✓ Trouvée: $APP_PATH"

echo "▶ Installation sur l'iPhone..."
DEVICE_ID=$(xcrun xctrace list devices 2>/dev/null | grep "$DEVICE_NAME" | head -1 | sed -n 's/.*(\([^)]*\)).*/\1/p')
if [ -n "$DEVICE_ID" ]; then
    if xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH" 2>/dev/null; then
        echo "✓ App installée sur $DEVICE_NAME"
        echo ""
        echo "  Lancez Capsule AI depuis l'écran d'accueil de votre iPhone."
    else
        echo "⚠ Installation via devicectl échouée."
        echo ""
        echo "  Alternative : ouvrez le projet dans Xcode et appuyez sur ▶ (Run)"
        echo "  ou glissez $APP_PATH dans l'Apps de votre appareil via Apple Configurator."
    fi
else
    echo "⚠ ID appareil non trouvé. Ouvrez Xcode et lancez avec ▶ sur votre iPhone."
fi
