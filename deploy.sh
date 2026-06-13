#!/bin/bash
# ════════════════════════════════════════════════════════
# Hostel Manager — Deployment Scripts v2
# Run from WSL terminal
# ════════════════════════════════════════════════════════

PROJECT_DIR="/mnt/c/Users/ahmed/GMRental/hostel_management"
export PATH="$HOME/.shorebird/bin:$PATH"

echo "════════════════════════════════════════════════════════"
echo "  Hostel Manager — Deployment Pipeline v2"
echo "════════════════════════════════════════════════════════"
echo ""

# Check shorebird
if ! command -v shorebird &> /dev/null; then
  echo "⚠ Shorebird CLI not found. Installing..."
  curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh | bash
  export PATH="$HOME/.shorebird/bin:$PATH"
fi

echo "Shorebird version: $(shorebird --version 2>&1 | head -1)"
echo ""
echo "Select deployment target:"
echo "  1) Android APK (direct install)"
echo "  2) Android AAB (Play Store)"
echo "  3) iOS IPA (TestFlight)"
echo "  4) Shorebird Release — Android (first-time OTA setup)"
echo "  5) Shorebird Release — iOS (first-time OTA setup)"
echo "  6) Shorebird Patch — Android + iOS (push OTA update)"
echo "  7) Full Release (APK + Shorebird patch both platforms)"
echo "  8) Login to Shorebird"
echo "  9) Exit"
echo ""
read -p "Enter choice [1-9]: " choice

cd "$PROJECT_DIR"

case $choice in
  1)
    echo "Building Android APK..."
    cmd.exe /c "cd C:\Users\ahmed\GMRental\hostel_management && C:\Users\ahmed\FlutterSDK\flutter\bin\flutter build apk --release"
    echo "✓ APK: build/app/outputs/flutter-apk/app-release.apk"
    ;;
  2)
    echo "Building Android App Bundle..."
    cmd.exe /c "cd C:\Users\ahmed\GMRental\hostel_management && C:\Users\ahmed\FlutterSDK\flutter\bin\flutter build appbundle --release"
    echo "✓ AAB: build/app/outputs/bundle/release/app-release.aab"
    ;;
  3)
    echo "Building iOS IPA..."
    cmd.exe /c "cd C:\Users\ahmed\GMRental\hostel_management && C:\Users\ahmed\FlutterSDK\flutter\bin\flutter build ipa --release"
    echo "✓ IPA built. Open Xcode to upload to TestFlight."
    ;;
  4)
    echo "Creating Shorebird Android release..."
    echo "⚠ Make sure you're logged in: shorebird login"
    shorebird release android
    echo "✓ Android release created. Devices can now install via Shorebird."
    ;;
  5)
    echo "Creating Shorebird iOS release..."
    echo "⚠ Make sure you're logged in: shorebird login"
    shorebird release ios
    echo "✓ iOS release created. Devices can now install via Shorebird."
    ;;
  6)
    echo "Pushing Shorebird patch to Android + iOS..."
    echo "⚠ Requires existing Shorebird release. Run option 4/5 first."
    echo ""
    echo "Patching Android..."
    shorebird patch android
    echo ""
    echo "Patching iOS..."
    shorebird patch ios
    echo ""
    echo "✓ Patches pushed! Devices will auto-update on next launch."
    ;;
  7)
    echo "═══ Full Release: APK + Shorebird OTA ═══"
    echo ""
    echo "Step 1: Building Android APK..."
    cmd.exe /c "cd C:\Users\ahmed\GMRental\hostel_management && C:\Users\ahmed\FlutterSDK\flutter\bin\flutter build apk --release"
    echo "✓ APK ready."
    echo ""
    echo "Step 2: Shorebird releases..."
    shorebird release android
    shorebird release ios
    echo ""
    echo "Step 3: Pushing patches..."
    shorebird patch android
    shorebird patch ios
    echo ""
    echo "════════════════════════════════════════════════════════"
    echo "  ✓ Full release complete!"
    echo "  APK: build/app/outputs/flutter-apk/app-release.apk"
    echo "  Shorebird: Android + iOS releases + patches pushed"
    echo "════════════════════════════════════════════════════════"
    ;;
  8)
    echo "Opening Shorebird login..."
    shorebird login
    ;;
  9)
    echo "Exiting."
    exit 0
    ;;
  *)
    echo "Invalid choice."
    exit 1
    ;;
esac
