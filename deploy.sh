#!/bin/bash
# ════════════════════════════════════════════════════════
# Hostel Manager — Deployment Scripts
# Run from WSL terminal
# ════════════════════════════════════════════════════════

PROJECT_DIR="/mnt/c/Users/ahmed/GMRental/hostel_management"

echo "════════════════════════════════════════════════════════"
echo "  Hostel Manager — Deployment Pipeline"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Select deployment target:"
echo "  1) Android (APK — direct install)"
echo "  2) Android (AAB — Play Store)"
echo "  3) iOS (IPA — TestFlight)"
echo "  4) Shorebird Patch (OTA — Android + iOS)"
echo "  5) Full Release (APK + Shorebird patch)"
echo "  6) Exit"
echo ""
read -p "Enter choice [1-6]: " choice

cd "$PROJECT_DIR"

case $choice in
  1)
    echo ""
    echo "Building Android APK..."
    flutter build apk --release
    echo ""
    echo "✓ APK built at: build/app/outputs/flutter-apk/app-release.apk"
    echo "  Transfer this file to your Android device and install."
    ;;
  2)
    echo ""
    echo "Building Android App Bundle..."
    flutter build appbundle --release
    echo ""
    echo "✓ AAB built at: build/app/outputs/bundle/release/app-release.aab"
    echo "  Upload to Google Play Console."
    ;;
  3)
    echo ""
    echo "Building iOS IPA..."
    flutter build ipa --release
    echo ""
    echo "✓ IPA built. Open Xcode to upload to TestFlight."
    ;;
  4)
    echo ""
    echo "Pushing Shorebird patch (OTA update)..."
    echo ""
    
    # Check if shorebird is installed
    if ! command -v shorebird &> /dev/null; then
      echo "⚠ Shorebird CLI not found. Installing..."
      curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh | bash
      export PATH="$HOME/.shorebird/bin:$PATH"
    fi
    
    echo ""
    echo "Patching Android..."
    shorebird patch android --release
    
    echo ""
    echo "Patching iOS..."
    shorebird patch ios --release
    
    echo ""
    echo "✓ Shorebird patches pushed!"
    echo "  Devices will receive updates automatically on next app launch."
    ;;
  5)
    echo ""
    echo "Full Release: APK + Shorebird OTA"
    echo ""
    
    echo "Step 1: Building Android APK..."
    flutter build apk --release
    echo "✓ APK ready."
    
    echo ""
    echo "Step 2: Pushing Shorebird patches..."
    if ! command -v shorebird &> /dev/null; then
      echo "⚠ Shorebird CLI not found. Installing..."
      curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh | bash
      export PATH="$HOME/.shorebird/bin:$PATH"
    fi
    
    shorebird patch android --release
    shorebird patch ios --release
    
    echo ""
    echo "════════════════════════════════════════════════════════"
    echo "  ✓ Full release complete!"
    echo "  APK: build/app/outputs/flutter-apk/app-release.apk"
    echo "  Shorebird patches pushed to Android + iOS"
    echo "════════════════════════════════════════════════════════"
    ;;
  6)
    echo "Exiting."
    exit 0
    ;;
  *)
    echo "Invalid choice."
    exit 1
    ;;
esac
