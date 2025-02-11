#!/bin/bash

# sdk-setup.sh - Automated Android SDK setup for Flutter development

# Exit on error and show executed commands
set -eo pipefail

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root/sudo"
    exit 1
fi

# Install required system packages
echo "Installing system dependencies..."
pacman -Sy --noconfirm git unzip jdk11-openjdk jre11-openjdk-headless

# Install AUR packages (using yay)
if ! command -v yay &> /dev/null; then
    echo "Error: yay AUR helper required. Please install yay first."
    exit 1
fi

echo "Installing Android SDK from AUR..."
yay -S --noconfirm android-sdk android-sdk-platform-tools

# Setup Android SDK
USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
ANDROID_SDK_ROOT="$USER_HOME/Android/Sdk"

echo "Configuring Android SDK at $ANDROID_SDK_ROOT..."
mkdir -p "$ANDROID_SDK_ROOT"
chown -R "$SUDO_USER:$SUDO_USER" "$USER_HOME/Android"

# Install SDK components
echo "Installing Android SDK components..."
sudo -u "$SUDO_USER" sdkmanager --sdk_root="$ANDROID_SDK_ROOT" \
  "platform-tools" \
  "build-tools;34.0.0" \
  "platforms;android-34" \
  "emulator"

# Set environment variables
echo "Configuring environment variables..."
for RC_FILE in "$USER_HOME/.bashrc" "$USER_HOME/.zshrc"; do
    cat << EOF >> "$RC_FILE"
# Android SDK configuration
export ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT"
export PATH="\$PATH:\$ANDROID_SDK_ROOT/platform-tools"
export PATH="\$PATH:\$ANDROID_SDK_ROOT/emulator"
export PATH="\$PATH:\$ANDROID_SDK_ROOT/cmdline-tools/latest/bin"
EOF
done

# Accept licenses
echo "Accepting Android SDK licenses..."
yes | sudo -u "$SUDO_USER" sdkmanager --licenses --sdk_root="$ANDROID_SDK_ROOT"

# Install Chrome
echo "Installing Google Chrome..."
yay -S --noconfirm google-chrome

# Configure Java
echo "Configuring Java environment..."
archlinux-java set java-11-openjdk
echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk" | tee -a "$USER_HOME/.bashrc" "$USER_HOME/.zshrc"

# Update Flutter configuration
echo "Updating Flutter configuration..."
sudo -u "$SUDO_USER" flutter config --android-sdk "$ANDROID_SDK_ROOT"
echo "export CHROME_EXECUTABLE=/usr/bin/google-chrome-stable" | tee -a "$USER_HOME/.bashrc" "$USER_HOME/.zshrc"

echo ""
echo "Setup completed successfully!"
echo "Restart your terminal or run:"
echo "source ~/.bashrc  # or source ~/.zshrc"
echo "Then verify with: flutter doctor"
