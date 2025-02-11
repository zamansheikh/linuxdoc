To manually install the Android SDK on Arch Linux/Manjaro without Android Studio, follow these steps:

### 1. Install Required Packages
First install dependencies and the Android SDK command-line tools:
```bash
sudo pacman -S git unzip java-environment=11 jre-openjdk-headless
yay -S android-sdk android-sdk-platform-tools  # Using AUR helper (yay/paru)
```

If you don't have an AUR helper:
```bash
git clone https://aur.archlinux.org/android-sdk.git
cd android-sdk
makepkg -si
```

### 2. Install Android SDK Components
```bash
# Set Android SDK path (default is ~/Android/Sdk)
export ANDROID_SDK_ROOT=$HOME/Android/Sdk
mkdir -p $ANDROID_SDK_ROOT

# Install essential components
sdkmanager --sdk_root=$ANDROID_SDK_ROOT \
  "platform-tools" \
  "build-tools;34.0.0" \
  "platforms;android-34" \
  "emulator"
```

### 3. Configure Environment Variables
Add these to your shell config (`.bashrc`, `.zshrc`, etc.):
```bash
export ANDROID_SDK_ROOT=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_SDK_ROOT/platform-tools
export PATH=$PATH:$ANDROID_SDK_ROOT/emulator
export PATH=$PATH:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin
```

### 4. Accept Licenses
```bash
yes | sdkmanager --licenses --sdk_root=$ANDROID_SDK_ROOT
flutter doctor --android-licenses
```

### 5. Install Chrome for Web Development
```bash
yay -S google-chrome  # or use chromium:
# sudo pacman -S chromium
```

### 6. Verify Setup
```bash
flutter doctor
```

### Troubleshooting Tips:
1. If you get Java errors:
```bash
sudo archlinux-java set java-11-openjdk
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk
```

2. If SDK path is not detected:
```bash
flutter config --android-sdk $ANDROID_SDK_ROOT
```

3. For web development issues:
```bash
export CHROME_EXECUTABLE=/usr/bin/google-chrome-stable
```

### Alternative: Install via SDKMAN (Java version management)
```bash
curl -s "https://get.sdkman.io" | bash
sdk install java 11.0.22-zulu
sdk install ant
```

This setup gives you a minimal Android development environment without Android Studio. You'll have:
- ADB and Fastboot
- Platform tools
- Build tools
- Android platform SDK
- Emulator (optional)

You can later add more components using `sdkmanager`:
```bash
sdkmanager --sdk_root=$ANDROID_SDK_ROOT "system-images;android-34;google_apis;x86_64"
```
