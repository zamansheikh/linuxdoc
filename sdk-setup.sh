#!/bin/bash
# sdk-setup.sh
# This script installs the Android SDK and required components on Arch Linux/Manjaro.
# It installs required packages, the Android SDK (and platform tools) via AUR,
# sets up essential Android SDK components, accepts licenses, and installs Chrome
# (or Chromium) for Flutter web development.
#
# Note: This script assumes you have sudo privileges and, optionally, an AUR helper (yay).
#       It will modify your shell configuration file (e.g., ~/.bashrc or ~/.zshrc)
#       to export the necessary environment variables.

set -e

echo "============================================"
echo "Starting Android SDK setup on Arch Linux..."
echo "============================================"

#############################
# 1. Update System Packages #
#############################
echo "[1/7] Updating system packages..."
sudo pacman -Syu --noconfirm

#######################################
# 2. Install Required Dependencies    #
#######################################
echo "[2/7] Installing required packages via pacman..."
# Install git, unzip, xz, zip, glu, and OpenJDK (headless runtime and JDK 11)
sudo pacman -S --noconfirm git unzip xz zip glu jre-openjdk-headless jdk11-openjdk

#########################################
# 3. Install Android SDK from the AUR   #
#########################################
echo "[3/7] Installing Android SDK and Platform Tools..."

# Check if yay (an AUR helper) is installed.
if command -v yay >/dev/null 2>&1; then
    echo "Using yay to install AUR packages..."
    yay -S --noconfirm android-sdk android-sdk-platform-tools
else
    echo "Yay not found. Falling back to manual AUR installation."

    # Install android-sdk manually from AUR
    if [ ! -d "android-sdk" ]; then
        git clone https://aur.archlinux.org/android-sdk.git
    fi
    cd android-sdk
    makepkg -si --noconfirm
    cd ..

    # Install android-sdk-platform-tools manually from AUR
    if [ ! -d "android-sdk-platform-tools" ]; then
        git clone https://aur.archlinux.org/android-sdk-platform-tools.git
    fi
    cd android-sdk-platform-tools
    makepkg -si --noconfirm
    cd ..
fi

#########################################
# 4. Setup Android SDK Environment      #
#########################################
echo "[4/7] Setting up Android SDK environment..."

# Prefer the standard Arch installation location if it exists.
if [ -d "/opt/android-sdk" ]; then
    export ANDROID_SDK_ROOT="/opt/android-sdk"
else
    export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
    mkdir -p "$ANDROID_SDK_ROOT"
fi
echo "Setting ANDROID_SDK_ROOT to $ANDROID_SDK_ROOT"

# If sdkmanager is not in PATH, try to add it from known locations.
if ! command -v sdkmanager >/dev/null 2>&1; then
    if [ -x "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" ]; then
        export PATH="$PATH:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin"
    elif [ -x "$ANDROID_SDK_ROOT/tools/bin/sdkmanager" ]; then
        export PATH="$PATH:$ANDROID_SDK_ROOT/tools/bin"
    fi
fi

# Verify sdkmanager is now available.
if ! command -v sdkmanager >/dev/null 2>&1; then
    echo "Error: sdkmanager not found in PATH. Please verify the Android SDK installation."
    exit 1
fi

#####################################################
# 5. Install Android SDK Components via sdkmanager  #
#####################################################
echo "[5/7] Installing essential Android SDK components..."
sdkmanager --sdk_root="$ANDROID_SDK_ROOT" \
  "platform-tools" \
  "build-tools;34.0.0" \
  "platforms;android-34" \
  "emulator"

#################################
# 6. Accept Licenses            #
#################################
echo "[6/7] Accepting Android SDK licenses..."
yes | sdkmanager --licenses --sdk_root="$ANDROID_SDK_ROOT"

# If Flutter is installed, also accept Flutter's Android licenses.
if command -v flutter >/dev/null 2>&1; then
    flutter doctor --android-licenses
else
    echo "Flutter not found in PATH. Skipping 'flutter doctor --android-licenses'."
fi

#########################################
# 7. Install Chrome for Web Development #
#########################################
echo "[7/7] Installing web development browser..."
if command -v yay >/dev/null 2>&1; then
    echo "Installing Google Chrome via yay..."
    yay -S --noconfirm google-chrome
else
    echo "Yay not found. Installing Chromium via pacman..."
    sudo pacman -S --noconfirm chromium
fi

######################################################
# 8. Update Shell Configuration for Environment Vars #
######################################################
# Determine which shell configuration file to update.
if [ -n "$BASH_VERSION" ]; then
    SHELL_CONFIG="$HOME/.bashrc"
elif [ -n "$ZSH_VERSION" ]; then
    SHELL_CONFIG="$HOME/.zshrc"
else
    SHELL_CONFIG="$HOME/.profile"
fi

echo "Updating shell configuration file: $SHELL_CONFIG"

# Append environment variable exports if not already present.
grep -qxF "export ANDROID_SDK_ROOT=" "$SHELL_CONFIG" || \
    echo "export ANDROID_SDK_ROOT=$ANDROID_SDK_ROOT" >> "$SHELL_CONFIG"

grep -qxF 'export PATH=$PATH:$ANDROID_SDK_ROOT/platform-tools' "$SHELL_CONFIG" || \
    echo 'export PATH=$PATH:$ANDROID_SDK_ROOT/platform-tools' >> "$SHELL_CONFIG"

grep -qxF 'export PATH=$PATH:$ANDROID_SDK_ROOT/emulator' "$SHELL_CONFIG" || \
    echo 'export PATH=$PATH:$ANDROID_SDK_ROOT/emulator' >> "$SHELL_CONFIG"

# Add the sdkmanager location to PATH, checking for both new and legacy paths.
if [ -d "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin" ]; then
    grep -qxF 'export PATH=$PATH:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin' "$SHELL_CONFIG" || \
        echo 'export PATH=$PATH:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin' >> "$SHELL_CONFIG"
elif [ -d "$ANDROID_SDK_ROOT/tools/bin" ]; then
    grep -qxF 'export PATH=$PATH:$ANDROID_SDK_ROOT/tools/bin' "$SHELL_CONFIG" || \
        echo 'export PATH=$PATH:$ANDROID_SDK_ROOT/tools/bin' >> "$SHELL_CONFIG"
fi

######################################################
# 9. Troubleshooting: Set Java Version (if necessary)#
######################################################
if command -v archlinux-java >/dev/null 2>&1; then
    echo "Setting default Java to java-11-openjdk..."
    sudo archlinux-java set java-11-openjdk
    export JAVA_HOME=/usr/lib/jvm/java-11-openjdk
    grep -qxF 'export JAVA_HOME=/usr/lib/jvm/java-11-openjdk' "$SHELL_CONFIG" || \
        echo 'export JAVA_HOME=/usr/lib/jvm/java-11-openjdk' >> "$SHELL_CONFIG"
fi

#################################
# 10. Final Verification        #
#################################
echo "============================================"
echo "Android SDK setup is complete!"
echo "Please restart your terminal or run:"
echo "    source $SHELL_CONFIG"
echo "to load the new environment variables."
echo "============================================"

# Optionally, run flutter doctor if Flutter is installed.
if command -v flutter >/dev/null 2>&1; then
    flutter doctor
fi

exit 0
