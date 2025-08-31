#!/bin/bash

# Build script for local testing
set -e

echo "VibeVoice Text Reader - Local Build Script"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check Flutter installation
if ! command -v flutter &> /dev/null; then
    print_error "Flutter is not installed. Please install Flutter first."
    exit 1
fi

print_status "Flutter is installed"

# Get Flutter dependencies
print_status "Getting Flutter dependencies..."
flutter pub get

# Run tests
print_status "Running tests..."
flutter test || print_warning "Some tests failed"

# Build APK
echo ""
echo "Select build type:"
echo "1) Debug APK"
echo "2) Release APK"
echo "3) Release APK (split per ABI)"
echo "4) App Bundle (AAB)"
read -p "Enter choice [1-4]: " choice

case $choice in
    1)
        print_status "Building Debug APK..."
        flutter build apk --debug
        APK_PATH="build/app/outputs/flutter-apk/app-debug.apk"
        ;;
    2)
        print_status "Building Release APK..."
        flutter build apk --release
        APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
        ;;
    3)
        print_status "Building Release APK (split per ABI)..."
        flutter build apk --release --split-per-abi
        APK_PATH="build/app/outputs/flutter-apk/"
        ;;
    4)
        print_status "Building App Bundle..."
        flutter build appbundle --release
        APK_PATH="build/app/outputs/bundle/release/app-release.aab"
        ;;
    *)
        print_error "Invalid choice"
        exit 1
        ;;
esac

echo ""
print_status "Build completed successfully!"
echo "Output location: $APK_PATH"

# Offer to install on connected device
if [ "$choice" != "4" ]; then
    echo ""
    read -p "Install on connected device? (y/n): " install_choice
    if [ "$install_choice" = "y" ]; then
        devices=$(flutter devices | grep -E "•" | wc -l)
        if [ "$devices" -gt 0 ]; then
            print_status "Installing on device..."
            if [ "$choice" = "3" ]; then
                # For split APKs, install the appropriate one
                ARCH=$(adb shell getprop ro.product.cpu.abi)
                case $ARCH in
                    arm64-v8a)
                        APK_FILE="app-arm64-v8a-release.apk"
                        ;;
                    armeabi-v7a)
                        APK_FILE="app-armeabi-v7a-release.apk"
                        ;;
                    x86_64)
                        APK_FILE="app-x86_64-release.apk"
                        ;;
                    *)
                        print_error "Unknown architecture: $ARCH"
                        exit 1
                        ;;
                esac
                flutter install --release
            else
                flutter install
            fi
            print_status "App installed successfully!"
        else
            print_warning "No devices connected"
        fi
    fi
fi

echo ""
echo "Next steps:"
echo "1. Test the app on your device"
echo "2. Run 'cd android && fastlane build_apk' for Fastlane build"
echo "3. Configure signing for Play Store release"