# OdysseyDecomp Android Build Guide

## Prerequisites

### Required Tools
- Android NDK r25c+ (recommended: r25.2.9519653)
- CMake 3.22+
- JDK 17+
- Android SDK with platform-tools
- Gradle 8.2+

### Environment Variables
```bash
export ANDROID_NDK_HOME=~/Android/Sdk/ndk/25.2.9519653
export ANDROID_SDK_ROOT=~/Android/Sdk
export PATH=$PATH:$ANDROID_SDK_ROOT/platform-tools
```

## Build Instructions

### 1. Clone Repository
```bash
git clone https://github.com/your-org/odysseydecomp.git
cd odysseydecomp
```

### 2. Configure Build
```bash
cd android
./build_android.sh --help
```

### 3. Build Release APK
```bash
export ANDROID_NDK_HOME=~/Android/Sdk/ndk/25.2.9519653
./build_android.sh --release --verbose
```

Expected output:
```
[build_android.sh] Building OdysseyDecomp for Android
[build_android.sh] NDK path: ~/Android/Sdk/ndk/25.2.9519653
[build_android.sh] Building with CMake...
[build_android.sh] Generating APK...
[build_android.sh] APK built successfully: android/app/build/outputs/apk/release/app-release.apk
```

### 4. Install on Device
```bash
adb install -r android/app/build/outputs/apk/release/app-release.apk
```

### 5. Launch Application
```bash
adb shell am start -n com.odysseydecomp.game/com.odysseydecomp.game.MainActivity
```

## Troubleshooting

### Problem: CMake not found
**Solution:**
```bash
sudo apt install cmake
# or
brew install cmake
```

### Problem: NDK not found
**Solution:**
```bash
echo $ANDROID_NDK_HOME
# Should output a valid path to NDK installation
```

If not set, install NDK via Android Studio:
1. Open Android Studio
2. Go to Settings -> Appearance & Behavior -> System Settings -> Android SDK
3. SDK Tools tab -> Android NDK (Side by side) -> Install

### Problem: Vulkan not supported
**Solution:**
- Device must support Vulkan 1.1+ (API level 24+)
- Check device support: `adb shell cat /proc/vulkan`
- If not supported, build with OpenGL ES fallback (not yet implemented)

### Problem: Compilation errors with sead/agl
**Solution:**
- Verify all submodules are initialized:
```bash
git submodule update --init --recursive
```
- Check CMakeLists.txt includes all required libraries

### Problem: APK too large
**Solution:**
- Enable APK splitting by ABI in `build.gradle`:
```gradle
android {
    splits {
        abi {
            enable true
            reset()
            include 'arm64-v8a', 'x86_64'
            universalApk false
        }
    }
}
```

### Problem: Low FPS on mid-range devices
**Solution:**
- Reduce texture resolution in `PERFORMANCE.md` section 6
- Enable ASTC texture compression
- Reduce MSAA samples from 4x to 2x
- Enable dynamic resolution scaling

## Build Variants

### Debug Build
```bash
./build_android.sh --debug --verbose
```
- Includes debug symbols
- Enables Vulkan validation layers
- Optimizations disabled

### Release Build
```bash
./build_android.sh --release
```
- Stripped symbols
- Optimized for size and speed
- Validation layers disabled

### Clean Build
```bash
./build_android.sh --clean
```
- Removes all build artifacts
- Forces full rebuild

## Device Compatibility

### Minimum Requirements
- Android 7.0 (API 24) or higher
- Vulkan 1.1 support
- ARM64 (arm64-v8a) architecture
- 2GB RAM minimum
- 200MB free storage

### Recommended Requirements
- Android 12+ (API 31+)
- Vulkan 1.3 support
- 4GB RAM
- 1GB free storage
- High-end GPU (Adreno 730+, Mali-G78+)

## Performance Tuning

### Low-End Devices (30 FPS target)
- Resolution: 720p (1280x720)
- MSAA: 2x
- Texture quality: Low
- Enable dynamic resolution scaling

### Mid-Range Devices (45 FPS target)
- Resolution: 1080p (1920x1080)
- MSAA: 4x
- Texture quality: Medium
- Enable Vulkan dynamic rendering

### High-End Devices (60 FPS target)
- Resolution: 1440p+ (2560x1440)
- MSAA: 8x
- Texture quality: High
- Enable VRS (Variable Rate Shading)

## Development Workflow

### 1. Make Code Changes
```bash
# Edit source files in src/
# Test on host machine first
```

### 2. Rebuild Native Library
```bash
cd android
./build_android.sh --release
```

### 3. Install on Device
```bash
adb install -r android/app/build/outputs/apk/release/app-release.apk
```

### 4. Debug with Logcat
```bash
adb logcat -s OdysseyDecomp,OdysseyNative,Vulkan
```

### 5. Profile Performance
```bash
adb shell dumpsys gfxinfo com.odysseydecomp.game
```

## Contributing

### Code Style
- C++17 standard
- Follow existing sead/agl code conventions
- Add comments for complex Vulkan operations
- Use RAII for resource management

### Testing
- Test on at least 2 different device tiers
- Verify FPS stability over 10 minutes
- Check memory usage remains stable
- Validate Vulkan validation layers pass

### Pull Requests
1. Fork the repository
2. Create feature branch
3. Implement changes
4. Test on device
5. Submit PR with test results

## License

This project is for educational purposes only. See LICENSE file for details.