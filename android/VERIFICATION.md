# Android Port Verification Pipeline

## 1. Host Cross-Compilation Check

### Prerequisites
- Android NDK r25c+ installed
- CMake 3.22+ installed
- Vulkan SDK (optional for validation layers)

### Verification Steps

#### 1.1 NDK Detection
```bash
# Verify NDK is installed and accessible
echo $ANDROID_NDK_HOME
# Expected: ~/Android/Sdk/ndk/25.2.9519653 (or similar)

# Verify NDK toolchain exists
ls $ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/clang++
# Expected: clang++ binary present
```

#### 1.2 CMake Configuration
```bash
cd /workspace/OdysseyDecomp/android
cmake -B build -S . \
  -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-24 \
  -DCMAKE_BUILD_TYPE=Release
```

Expected output: CMake configuration succeeds with no errors.

#### 1.3 Compilation Check
```bash
cmake --build build --config Release -j$(nproc)
```

Expected: `odyssey_main` shared library built successfully.

## 2. Vulkan Layer Validation

### 2.1 Enable Validation Layers
```bash
# In VulkanRenderer.cpp, add during instance creation:
VkDebugUtilsMessengerCreateInfoEXT debugInfo{VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT};
debugInfo.messageSeverity = VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT | VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT;
debugInfo.messageType = VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT | VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT;
debugInfo.pfnCallback = [](VkDebugUtilsMessageSeverityFlagBitsEXT severity, VkDebugUtilsMessageTypeFlagsEXT types, const VkDebugUtilsMessengerCallbackDataEXT* data, void* userData) {
    __android_log_print(ANDROID_LOG_ERROR, "Vulkan", "%s", data->pMessage);
};
```

### 2.2 Device Logcat Filtering
```bash
adb logcat -s OdysseyDecomp,OdysseyNative,Vulkan
```

Expected: No validation errors during runtime.

## 3. Android Device Deployment

### 3.1 Build APK
```bash
cd /workspace/OdysseyDecomp/android
./build_android.sh --release --verbose
```

Expected: APK generated at `android/app/build/outputs/apk/release/app-release.apk`.

### 3.2 Install on Device
```bash
adb install -r android/app/build/outputs/apk/release/app-release.apk
```

Expected: APK installed successfully.

### 3.3 Launch Application
```bash
adb shell am start -n com.odysseydecomp.game/com.odysseydecomp.game.MainActivity
```

Expected: Application launches and displays main screen.

## 4. Performance Profiling

### 4.1 FPS Monitoring
```bash
adb shell dumpsys fps | grep com.odysseydecomp.game
```

Expected: Stable 30 FPS on mid-range devices, 60 FPS on high-end devices.

### 4.2 GPU Profiling
```bash
adb shell cat /proc/gpu_mem
```

Expected: Memory usage under 256MB for mid-range devices.

### 4.3 CPU Profiling
```bash
adb shell top -d 5 -n 1 -m -o %CPU | grep odyssey
```

Expected: CPU usage under 70% on mid-range devices.

## 5. Known Issues & Troubleshooting

### 5.1 Vulkan Version Compatibility
- **Problem**: Some devices report Vulkan 1.0 only
- **Solution**: Add runtime check in `VulkanRenderer::createInstance()`:
  ```cpp
  if (deviceProperties.apiVersion < VK_MAKE_VERSION(1, 1, 0)) {
      __android_log_print(ANDROID_LOG_WARN, "Vulkan", "Device supports Vulkan %d.%d, some features may be unavailable",
          VK_VERSION_MAJOR(deviceProperties.apiVersion), VK_VERSION_MINOR(deviceProperties.apiVersion));
  }
  ```

### 5.2 Swapchain Recreation
- **Problem**: App crashes on orientation change
- **Solution**: Handle `VK_ERROR_OUT_OF_DATE_KHR` in main loop:
  ```cpp
  if (result == VK_ERROR_OUT_OF_DATE_KHR) {
      recreateSwapchain();
      continue;
  }
  ```

### 5.3 Memory Pressure
- **Problem**: App killed by system under memory pressure
- **Solution**: Implement `onTrimMemory` in `MainActivity.java`:
  ```java
  @Override
  public void onTrimMemory(int level) {
      super.onTrimMemory(level);
      if (level >= TRIM_MEMORY_RUNNING_MODERATE) {
          // Notify native code to free cached resources
      }
  }
  ```