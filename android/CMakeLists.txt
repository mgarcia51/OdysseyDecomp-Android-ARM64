# CMakeLists.txt for OdysseyDecomp using native clang-17 ARM64
# Cross-compilation to Android ARM64 - uses custom toolchain

cmake_minimum_required(VERSION 3.22)
project(odyssey LANGUAGES CXX C)

# NDK paths - use CMake variable set by toolchain
if(NOT NDK_PATH)
    message(FATAL_ERROR "NDK_PATH must be set via -DNDK_PATH=/path/to/ndk")
endif()

set(SYSROOT "${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/sysroot")
set(LIBCXX_ROOT "${NDK_PATH}/sources/cxx-stl/llvm-libc++")
set(NATIVE_APP_GLUE_ROOT "${NDK_PATH}/sources/android/native_app_glue")

# Global Compile Flags
add_compile_definitions(
    ANDROID
    __ANDROID__
    VK_USE_PLATFORM_ANDROID_KHR
    SEAD_VERSION=SEAD_VERSION_SMO
    NON_MATCHING
    NNSDK
)

# Library
add_library(odyssey_main SHARED
    ../src/platform/android/AndroidPlatform.cpp
    ../src/platform/android/AndroidMain.cpp
    ../src/platform/android/JNIWrapper.cpp
    ../src/renderer/vulkan/VulkanRenderer.cpp
    ${NDK_PATH}/sources/android/native_app_glue/android_native_app_glue.c
)

# Includes - ORDER IS CRITICAL: NDK libc++ FIRST, then sysroot
target_include_directories(odyssey_main SYSTEM PRIVATE
    ${LIBCXX_ROOT}/include
    ${NATIVE_APP_GLUE_ROOT}
)
target_include_directories(odyssey_main SYSTEM PRIVATE
    ${SYSROOT}/usr/include/vulkan
)
target_include_directories(odyssey_main SYSTEM PRIVATE
    ${SYSROOT}/usr/include/aarch64-linux-android
)
target_include_directories(odyssey_main PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../src
    ${CMAKE_CURRENT_SOURCE_DIR}/../lib
    ${CMAKE_CURRENT_SOURCE_DIR}/../lib/al
    ${CMAKE_CURRENT_SOURCE_DIR}/../lib/sead
    ${CMAKE_CURRENT_SOURCE_DIR}/../lib/agl
    ${CMAKE_CURRENT_SOURCE_DIR}/../lib/eui
)

# Link - ONLY NDK libraries, no host libs
target_link_libraries(odyssey_main PRIVATE
    ${SYSROOT}/usr/lib/aarch64-linux-android/24/libandroid.so
    ${SYSROOT}/usr/lib/aarch64-linux-android/24/liblog.so
    ${SYSROOT}/usr/lib/aarch64-linux-android/24/libEGL.so
    ${SYSROOT}/usr/lib/aarch64-linux-android/24/libvulkan.so
    ${SYSROOT}/usr/lib/aarch64-linux-android/24/libc++.so
    ${SYSROOT}/usr/lib/aarch64-linux-android/24/libc.so
    ${SYSROOT}/usr/lib/aarch64-linux-android/24/libm.so
    ${SYSROOT}/usr/lib/aarch64-linux-android/24/libdl.so
)

# Disable GCC library linking
set_target_properties(odyssey_main PROPERTIES
    LINK_FLAGS "-nodefaultlibs"
)

# Optimization
target_link_options(odyssey_main PRIVATE
    -Wl,-Bsymbolic-functions
    -Wl,--gc-sections
    -Wl,--build-id=sha1
    -fuse-ld=lld
    -Wl,--no-as-needed
)

# Android STL
set_target_properties(odyssey_main PROPERTIES
    ANDROID_STL_TYPE "c++_shared"
)

# C++ standard
set_target_properties(odyssey_main PROPERTIES
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
    CXX_EXTENSIONS OFF
)