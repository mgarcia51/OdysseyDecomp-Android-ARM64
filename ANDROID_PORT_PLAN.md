# OdysseyDecomp Android Port & Vulkan Renderer Architecture Plan

## Executive Summary & Target Architecture

This document presents a complete, production-grade architectural and implementation blueprint for porting **OdysseyDecomp** (Super Mario Odyssey decompilation target) to **Android** utilizing an advanced **Vulkan 1.3** rendering backend.

The target system architecture decouples the Nintendo Switch (NVN/sead/agl) graphics stack and OS framework into an abstracted platform and rendering backend. On Android, execution is driven through `ANativeActivity` using `android_native_app_glue`, providing cross-process lifecycle management, input event dispatching, window surface acquisition, and high-performance Vulkan command queueing.

```
+-----------------------------------------------------------------------------------------+
|                                  OdysseyDecomp Engine Core                              |
|   (System / Scene / Player / Enemy / Layout / Stage / sead Framework Abstractions)      |
+-----------------------------------------------------------------------------------------+
                                           |
                    +----------------------+----------------------+
                    |                                             |
                    v                                             v
+---------------------------------------+     +---------------------------------------+
|        odyssey::platform::IPlatform   |     |      odyssey::renderer::IRenderer     |
+---------------------------------------+     +---------------------------------------+
                    |                                             |
                    v                                             v
+---------------------------------------+     +---------------------------------------+
|     AndroidPlatform & JNIWrapper      |     |             VulkanRenderer            |
|  (ANativeActivity, NativeWindow, JNI) |     |  (VkInstance, Swapchain, Pipelines)   |
+---------------------------------------+     +---------------------------------------+
                    |                                             |
                    v                                             v
+---------------------------------------+     +---------------------------------------+
|        Android Operating System       |     |         Vulkan 1.3 Driver (NDK)       |
|    (NDK Media, AssetManager, Input)   |     |    (Adreno / Mali GPU Hardware)       |
+---------------------------------------+     +---------------------------------------+
```

---

## 1. NDK & Vulkan Build Architecture

### 1.1 Multi-ABI & Toolchain Strategy

The Android build infrastructure leverages Android NDK (r25c+) with Clang 14+, targeting **ARM64 (`arm64-v8a`)** as the primary high-performance tier, with fallback build targets for `x86_64` (emulators). Min API level is set to **API 24 (Android 7.0)** to guarantee native Vulkan 1.0 support, with extended features targeting **API 31+ (Vulkan 1.3)** via dynamic feature checks.

```
Target ABIs:          arm64-v8a (Primary, Neon-optimized), x86_64 (Emulator)
Minimum SDK:          API Level 24 (Android 7.0 Nougat)
Target SDK:           API Level 34 (Android 14)
C++ Standard:         C++17 (GNU/Clang extensions disabled: -std=c++17)
STL Configuration:    c++_shared (libc++ dynamic runtime)
Opt Level:            -O3 -flto=thin -fvisibility=hidden -fPIC -fno-exceptions -fno-rtti
```

### 1.2 CMake Toolchain Integration (`android/CMakeLists.txt`)

The standalone CMake architecture integrates seamlessly with both NDK CLI builds (`build_android.sh`) and Gradle builds.

```cmake
# android/CMakeLists.txt
cmake_minimum_required(VERSION 3.22)
project(odyssey_android CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Global Compile Flags for Android Engine Architecture
add_compile_definitions(
    ANDROID
    __ANDROID__
    VK_USE_PLATFORM_ANDROID_KHR
    VK_NO_PROTOTYPES
    SEAD_VERSION=SEAD_VERSION_SMO
    NON_MATCHING
    NNSDK
)

# Core Library Definition (Shared Library for NativeActivity)
add_library(odyssey_main SHARED
    # Platform implementation
    src/platform/android/AndroidPlatform.cpp
    src/platform/android/AndroidMain.cpp
    src/platform/android/JNIWrapper.cpp
    
    # Renderer implementation
    src/renderer/vulkan/VulkanRenderer.cpp
    src/renderer/vulkan/VulkanDevice.cpp
    src/renderer/vulkan/VulkanSwapchain.cpp
    src/renderer/vulkan/VulkanPipeline.cpp
    src/renderer/vulkan/VulkanResources.cpp
    src/renderer/vulkan/VulkanCommands.cpp
    
    # Native Application Glue
    ${ANDROID_NDK}/sources/android/native_app_glue/android_native_app_glue.c
)

# Include Directories
target_include_directories(odyssey_main PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../src
    ${CMAKE_CURRENT_SOURCE_DIR}/../lib
    ${CMAKE_CURRENT_SOURCE_DIR}/../lib/al
    ${CMAKE_CURRENT_SOURCE_DIR}/../lib/sead
    ${CMAKE_CURRENT_SOURCE_DIR}/../lib/agl
    ${CMAKE_CURRENT_SOURCE_DIR}/../lib/eui
    ${ANDROID_NDK}/sources/android/native_app_glue
)

# System Libraries Linking
target_link_libraries(odyssey_main PRIVATE
    android
    log
    EGL
    vulkan
    aaudio
    camera2ndk
    mediandk
    atomic
    m
)

# Optimization & Symbols Export
target_link_options(odyssey_main PRIVATE
    -Wl,-Bsymbolic-functions
    -Wl,--gc-sections
    -Wl,--build-id=sha1
)
```

---

## 2. Core Abstractions & Interfaces

To resolve missing headers identified during workspace analysis, the abstract platform and rendering interfaces are formally established under `src/core/platform/IPlatform.hpp` and `src/core/renderer/IRenderer.hpp`.

### 2.1 Abstract Platform Interface (`src/core/platform/IPlatform.hpp`)

```cpp
#pragma once

#include <cstdint>

namespace odyssey::platform {

class IPlatform {
public:
    virtual ~IPlatform() = default;

    virtual void init(int argc, char** argv) = 0;
    virtual void pollEvents() = 0;
    virtual void swapBuffers() = 0;
    virtual void* getNativeWindow() = 0;
    virtual uint32_t getWidth() const = 0;
    virtual uint32_t getHeight() const = 0;
    virtual void setWindowTitle(const char* title) = 0;
    virtual bool shouldClose() const = 0;
    virtual double getTime() const = 0;
};

} // namespace odyssey::platform
```

### 2.2 Abstract Renderer Interface (`src/core/renderer/IRenderer.hpp`)

```cpp
#pragma once

#include <cstdint>
#include <vector>

namespace odyssey::renderer {

using TextureHandle = uint64_t;
using BufferHandle = uint64_t;
using PipelineHandle = uint64_t;

struct TextureDesc {
    uint32_t width = 0;
    uint32_t height = 0;
    uint32_t format = 0;
    const void* initialData = nullptr;
};

struct BufferDesc {
    size_t size = 0;
    uint32_t usageFlags = 0;
    const void* initialData = nullptr;
};

struct PipelineDesc {
    const char* vertexShaderPath = nullptr;
    const char* fragmentShaderPath = nullptr;
};

class Mesh;
class Material;

class IRenderer {
public:
    virtual ~IRenderer() = default;

    virtual bool initialize(void* windowHandle) = 0;
    virtual void shutdown() = 0;
    virtual void beginFrame() = 0;
    virtual void endFrame() = 0;
    virtual void drawMesh(const Mesh& mesh, const Material& material) = 0;
    virtual void submitDrawCommands() = 0;
    
    virtual TextureHandle createTexture(const TextureDesc& desc) = 0;
    virtual BufferHandle createBuffer(const BufferDesc& desc) = 0;
    virtual PipelineHandle createPipeline(const PipelineDesc& desc) = 0;
    
    virtual void setViewport(uint32_t width, uint32_t height) = 0;
    virtual void setScissor(uint32_t x, uint32_t y, uint32_t width, uint32_t height) = 0;
};

} // namespace odyssey::renderer
```

---

## 3. Android Platform Layer & Native Activity

### 3.1 Lifecycle & Event Loop (`AndroidMain.cpp`)

The native entry point coordinates application instantiation with Android's asynchronous `ANativeActivity` lifecycle callbacks via `android_native_app_glue`.

```cpp
#include <android_native_app_glue.h>
#include <android/log.h>
#include "platform/android/AndroidPlatform.hpp"
#include "core/Application.hpp"

#define LOG_TAG "OdysseyNative"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

static odyssey::platform::AndroidPlatform* g_platform = nullptr;

extern "C" void android_main(struct android_app* app) {
    // Retain glue state
    static odyssey::platform::AndroidPlatform platform;
    g_platform = &platform;
    
    app->userData = &platform;
    app->onAppCmd = [](android_app* app, int32_t cmd) {
        static_cast<odyssey::platform::AndroidPlatform*>(app->userData)->handleCmd(cmd);
    };
    app->onInputEvent = [](android_app* app, AInputEvent* event) {
        return static_cast<odyssey::platform::AndroidPlatform*>(app->userData)->handleInput(event);
    };
    
    platform.setNativeActivity(app->activity);
    platform.init(0, nullptr);
    
    odyssey::Application appInstance;
    
    // Event processing & rendering main loop
    while (!platform.shouldClose()) {
        int events;
        android_poll_source* source;
        
        // Non-blocking event poll when rendering; blocking poll when backgrounded
        int timeout = platform.isWindowReady() ? 0 : -1;
        while (ALooper_pollAll(timeout, nullptr, &events, (void**)&source) >= 0) {
            if (source != nullptr) {
                source->process(app, source);
            }
            if (app->destroyRequested != 0) {
                platform.setShouldClose(true);
                break;
            }
        }
        
        if (platform.isWindowReady() && !platform.shouldClose()) {
            if (!appInstance.isInitialized()) {
                appInstance.initialize(&platform);
            }
            appInstance.update();
            appInstance.render();
        }
    }
    
    appInstance.shutdown();
}
```

### 3.2 Platform Implementation (`AndroidPlatform.cpp`)

```cpp
#include "AndroidPlatform.hpp"
#include "JNIWrapper.hpp"
#include <android/native_window.h>
#include <chrono>

namespace odyssey::platform {

AndroidPlatform::AndroidPlatform() = default;
AndroidPlatform::~AndroidPlatform() = default;

void AndroidPlatform::init(int argc, char** argv) {
    startTime_ = getCurrentTime();
    initialized_ = true;
}

void AndroidPlatform::setNativeActivity(ANativeActivity* activity) {
    activity_ = activity;
    if (activity && activity->vm) {
        JNIWrapper::setJavaVM(activity->vm);
    }
}

void AndroidPlatform::handleCmd(int32_t cmd) {
    switch (cmd) {
        case APP_CMD_INIT_WINDOW:
            if (activity_->window) {
                window_ = activity_->window;
                width_ = ANativeWindow_getWidth(window_);
                height_ = ANativeWindow_getHeight(window_);
                windowReady_ = true;
            }
            break;
        case APP_CMD_TERM_WINDOW:
            windowReady_ = false;
            window_ = nullptr;
            break;
        case APP_CMD_GAINED_FOCUS:
            focused_ = true;
            break;
        case APP_CMD_LOST_FOCUS:
            focused_ = false;
            break;
        case APP_CMD_DESTROY:
            shouldClose_ = true;
            break;
        default:
            break;
    }
}

int32_t AndroidPlatform::handleInput(AInputEvent* event) {
    int32_t type = AInputEvent_getType(event);
    if (type == AINPUT_EVENT_TYPE_MOTION) {
        // Map touch events to engine touch input vector
        int32_t action = AMotionEvent_getAction(event);
        int32_t pointerIndex = (action & AMOTION_EVENT_ACTION_POINTER_INDEX_MASK) >> AMOTION_EVENT_ACTION_POINTER_INDEX_SHIFT;
        float x = AMotionEvent_getX(event, pointerIndex);
        float y = AMotionEvent_getY(event, pointerIndex);
        
        inputState_.touchX = x;
        inputState_.touchY = y;
        inputState_.touchDown = ((action & AMOTION_EVENT_ACTION_MASK) != AMOTION_EVENT_ACTION_UP);
        return 1;
    }
    return 0;
}

double AndroidPlatform::getCurrentTime() {
    auto now = std::chrono::high_resolution_clock::now();
    return std::chrono::duration<double>(now.time_since_epoch()).count();
}

} // namespace odyssey::platform
```

---

## 4. Vulkan 1.3 Renderer Backend Architecture

The Vulkan backend is engineered specifically for mobile tiled-based deferred renderers (TBDR GPUs like Qualcomm Adreno and ARM Mali). It incorporates dynamic rendering (`VK_KHR_dynamic_rendering`), explicit synchronization 2 (`VK_KHR_synchronization2`), and lockless command buffer recording.

### 4.1 Vulkan Instance & Surface Creation

```cpp
#include "VulkanRenderer.hpp"
#include <vulkan/vulkan_android.h>
#include <vector>
#include <stdexcept>

namespace odyssey::renderer {

bool VulkanRenderer::createInstance() {
    VkApplicationInfo appInfo{VK_STRUCTURE_TYPE_APPLICATION_INFO};
    appInfo.pApplicationName = "OdysseyDecomp";
    appInfo.applicationVersion = VK_MAKE_VERSION(1, 0, 0);
    appInfo.pEngineName = "OdysseyEngine";
    appInfo.engineVersion = VK_MAKE_VERSION(1, 0, 0);
    appInfo.apiVersion = VK_API_VERSION_1_3;

    std::vector<const char*> extensions = {
        VK_KHR_SURFACE_EXTENSION_NAME,
        VK_KHR_ANDROID_SURFACE_EXTENSION_NAME,
        VK_EXT_DEBUG_UTILS_EXTENSION_NAME
    };

    VkInstanceCreateInfo createInfo{VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO};
    createInfo.pApplicationInfo = &appInfo;
    createInfo.enabledExtensionCount = static_cast<uint32_t>(extensions.size());
    createInfo.ppEnabledExtensionNames = extensions.data();

    return vkCreateInstance(&createInfo, nullptr, &instance_) == VK_SUCCESS;
}

bool VulkanRenderer::createSurface(void* windowHandle) {
    VkAndroidSurfaceCreateInfoKHR createInfo{VK_STRUCTURE_TYPE_ANDROID_SURFACE_CREATE_INFO_KHR};
    createInfo.window = static_cast<ANativeWindow*>(windowHandle);
    return vkCreateAndroidSurfaceKHR(instance_, &createInfo, nullptr, &surface_) == VK_SUCCESS;
}

} // namespace odyssey::renderer
```

### 4.2 Vulkan Swapchain & Dynamic Rendering Setup

```cpp
bool VulkanRenderer::createSwapchain() {
    VkSurfaceCapabilitiesKHR capabilities;
    vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physicalDevice_, surface_, &capabilities);

    VkExtent2D extent = capabilities.currentExtent;
    
    VkSwapchainCreateInfoKHR createInfo{VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR};
    createInfo.surface = surface_;
    createInfo.minImageCount = capabilities.minImageCount + 1;
    createInfo.imageFormat = VK_FORMAT_R8G8B8A8_UNORM;
    createInfo.imageColorSpace = VK_COLOR_SPACE_SRGB_NONLINEAR_KHR;
    createInfo.imageExtent = extent;
    createInfo.imageArrayLayers = 1;
    createInfo.imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT;
    createInfo.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;
    createInfo.preTransform = capabilities.currentTransform;
    createInfo.compositeAlpha = VK_COMPOSITE_ALPHA_INHERIT_BIT_KHR;
    createInfo.presentMode = VK_PRESENT_MODE_FIFO_KHR; // Guaranteed on Android
    createInfo.clipped = VK_TRUE;

    if (vkCreateSwapchainKHR(device_, &createInfo, nullptr, &swapchain_) != VK_SUCCESS) {
        return false;
    }

    uint32_t imageCount = 0;
    vkGetSwapchainImagesKHR(device_, swapchain_, &imageCount, nullptr);
    swapchainImages_.resize(imageCount);
    vkGetSwapchainImagesKHR(device_, swapchain_, &imageCount, swapchainImages_.data());
    
    swapchainExtent_ = extent;
    return true;
}
```

### 4.3 Frame Synchronization Loop

```cpp
void VulkanRenderer::beginFrame() {
    vkWaitForFences(device_, 1, &inFlightFences_[currentFrame_], VK_TRUE, UINT64_MAX);

    VkResult result = vkAcquireNextImageKHR(
        device_, swapchain_, UINT64_MAX,
        imageAvailableSemaphores_[currentFrame_],
        VK_NULL_HANDLE, &currentImageIndex_);

    if (result == VK_ERROR_OUT_OF_DATE_KHR) {
        recreateSwapchain();
        return;
    }

    vkResetFences(device_, 1, &inFlightFences_[currentFrame_]);
    
    VkCommandBuffer cmd = commandBuffers_[currentFrame_];
    vkResetCommandBuffer(cmd, 0);

    VkCommandBufferBeginInfo beginInfo{VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO};
    beginInfo.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
    vkBeginCommandBuffer(cmd, &beginInfo);
}

void VulkanRenderer::endFrame() {
    VkCommandBuffer cmd = commandBuffers_[currentFrame_];
    vkEndCommandBuffer(cmd);

    VkPipelineStageFlags waitStages[] = {VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT};
    
    VkSubmitInfo submitInfo{VK_STRUCTURE_TYPE_SUBMIT_INFO};
    submitInfo.waitSemaphoreCount = 1;
    submitInfo.pWaitSemaphores = &imageAvailableSemaphores_[currentFrame_];
    submitInfo.pWaitDstStageMask = waitStages;
    submitInfo.commandBufferCount = 1;
    submitInfo.pCommandBuffers = &cmd;
    submitInfo.signalSemaphoreCount = 1;
    submitInfo.pSignalSemaphores = &renderFinishedSemaphores_[currentFrame_];

    vkQueueSubmit(graphicsQueue_, 1, &submitInfo, inFlightFences_[currentFrame_]);

    VkPresentInfoKHR presentInfo{VK_STRUCTURE_TYPE_PRESENT_INFO_KHR};
    presentInfo.waitSemaphoreCount = 1;
    presentInfo.pWaitSemaphores = &renderFinishedSemaphores_[currentFrame_];
    presentInfo.swapchainCount = 1;
    presentInfo.pSwapchains = &swapchain_;
    presentInfo.pImageIndices = &currentImageIndex_;

    vkQueuePresentKHR(presentQueue_, &presentInfo);

    currentFrame_ = (currentFrame_ + 1) % MAX_FRAMES_IN_FLIGHT;
}
```

---

## 5. JNI Bridge & Android OS Services

`JNIWrapper` bridges C++ logic with Android Java services for system vibration, UI toasts, display metrics, storage paths, and asset resolution.

### 5.1 Java Virtual Machine Cache & Thread Safety

```cpp
// src/platform/android/JNIWrapper.cpp
#include "JNIWrapper.hpp"
#include <mutex>
#include <android/log.h>

namespace odyssey::platform {

static JavaVM* g_javaVM = nullptr;
static std::mutex g_jniMutex;

void JNIWrapper::setJavaVM(JavaVM* vm) {
    std::lock_guard<std::mutex> lock(g_jniMutex);
    g_javaVM = vm;
}

JNIEnv* JNIWrapper::getJNIEnv() {
    if (!g_javaVM) return nullptr;
    JNIEnv* env = nullptr;
    jint status = g_javaVM->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6);
    if (status == JNI_EDETACHED) {
        if (g_javaVM->AttachCurrentThread(&env, nullptr) != JNI_OK) {
            return nullptr;
        }
    }
    return env;
}

void JNIWrapper::showToast(const char* message) {
    JNIEnv* env = getJNIEnv();
    if (!env || !message) return;
    
    // Delegate to Java MainActivity via JNI call
    jclass clazz = env->FindClass("com/odysseydecomp/game/MainActivity");
    if (!clazz) return;
    
    jmethodID method = env->GetStaticMethodID(clazz, "showToast", "(Ljava/lang/String;)V");
    if (method) {
        jstring jMsg = env->NewStringUTF(message);
        env->CallStaticVoidMethod(clazz, method, jMsg);
        env->DeleteLocalRef(jMsg);
    }
}

} // namespace odyssey::platform
```

---

## 6. Android Manifest & Java Activity Host

### 6.1 Android Manifest Configuration (`android/AndroidManifest.xml`)

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.odysseydecomp.game"
    android:versionCode="1"
    android:versionName="1.0.0">

    <!-- Permissions -->
    <uses-permission android:name="android.permission.VIBRATE" />
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />

    <!-- Features -->
    <uses-feature android:name="android.hardware.vulkan.version" android:version="0x00401000" android:required="true" />
    <uses-feature android:name="android.hardware.touchscreen" android:required="true" />
    <uses-feature android:name="android.hardware.gamepad" android:required="false" />

    <application
        android:allowBackup="false"
        android:fullBackupOnly="false"
        android:icon="@mipmap/ic_launcher"
        android:label="OdysseyDecomp"
        android:hasCode="true"
        android:appCategory="game"
        android:extractNativeLibs="true">

        <activity
            android:name="com.odysseydecomp.game.MainActivity"
            android:label="OdysseyDecomp"
            android:configChanges="orientation|keyboardHidden|screenSize|screenLayout|smallestScreenSize|uiMode"
            android:screenOrientation="sensorLandscape"
            android:launchMode="singleInstance"
            android:theme="@android:style/Theme.NoTitleBar.Fullscreen"
            android:exported="true">
            
            <!-- Tell NativeActivity the name of the shared object file -->
            <meta-data android:name="android.app.lib_name" android:value="odyssey_main" />
            
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
```

### 6.2 Host Java Activity (`MainActivity.java`)

```java
package com.odysseydecomp.game;

import android.app.NativeActivity;
import android.os.Bundle;
import android.view.View;
import android.widget.Toast;

public class MainActivity extends NativeActivity {
    private static MainActivity sInstance;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        sInstance = this;
        hideSystemUI();
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) {
            hideSystemUI();
        }
    }

    private void hideSystemUI() {
        getWindow().getDecorView().setSystemUiVisibility(
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
            | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
            | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
            | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
            | View.SYSTEM_UI_FLAG_FULLSCREEN
        );
    }

    public static void showToast(final String message) {
        if (sInstance != null) {
            sInstance.runOnUiThread(() -> 
                Toast.makeText(sInstance, message, Toast.LENGTH_SHORT).show()
            );
        }
    }
}
```

---

## 7. Gradle Build System Infrastructure

### 7.1 Root Project Gradle Configuration (`android/build.gradle`)

```groovy
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath 'com.android.tools.build:gradle:8.2.2'
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

task clean(type: Delete) {
    delete rootProject.buildDir
}
```

### 7.2 Application Module Gradle Setup (`android/app/build.gradle`)

```groovy
plugins {
    id 'com.android.application'
}

android {
    namespace 'com.odysseydecomp.game'
    compileSdk 34

    defaultConfig {
        applicationId "com.odysseydecomp.game"
        minSdk 24
        targetSdk 34
        versionCode 1
        versionName "1.0.0"

        ndk {
            abiFilters 'arm64-v8a', 'x86_64'
        }

        externalNativeBuild {
            cmake {
                cppFlags "-std=c++17 -fno-exceptions -fno-rtti"
                arguments "-DANDROID_STL=c++_shared",
                          "-DCMAKE_BUILD_TYPE=Release"
            }
        }
    }

    buildTypes {
        release {
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }

    externalNativeBuild {
        cmake {
            path "../CMakeLists.txt"
            version "3.22.1"
        }
    }

    sourceSets {
        main {
            manifest.srcFile '../AndroidManifest.xml'
            java.srcDirs = ['src']
            res.srcDirs = ['res']
            assets.srcDirs = ['../../data']
        }
    }
}

dependencies {
    implementation 'androidx.annotation:annotation:1.7.1'
}
```

---

## 8. Verification & Performance Optimization Strategy

### 8.1 Verification Pipeline

1. **Host Cross-Compilation Check**: Validate compilation using NDK Clang toolchain:
   ```bash
   ./build_android.sh --clean --verbose
   ```
2. **Vulkan Layer Validation**: Enable `VK_LAYER_KHRONOS_validation` during debug builds and attach via `adb logcat -s OdysseyDecomp,OdysseyNative,Vulkan`.
3. **Android Device Deployment & Execution**:
   ```bash
   adb install -r android/app/build/outputs/apk/debug/app-debug.apk
   adb shell am start -n com.odysseydecomp.game/com.odysseydecomp.game.MainActivity
   ```

### 8.2 Performance Optimization Guidelines (Mobile GPUs)

- **Memory Management**: Use **Vulkan Memory Allocator (VMA)** to eliminate small heap allocations and pool device memory into `VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT` chunks.
- **Pipeline Caching**: Serialise VkPipelineCache to `/data/data/com.odysseydecomp.game/cache/pipeline.cache` via `JNIWrapper::getCacheDir()` to mitigate Android shader compilation stutter.
- **Render Pass Layout Transitions**: Minimize explicit `vkCmdPipelineBarrier` operations by specifying clear load/store ops (`VK_ATTACHMENT_LOAD_OP_CLEAR`, `VK_ATTACHMENT_STORE_OP_STORE`) inside VkRenderPass subpass definitions.
