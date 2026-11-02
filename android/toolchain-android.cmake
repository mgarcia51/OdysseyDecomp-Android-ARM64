# Custom Android ARM64 toolchain for native clang-17
# Bypasses CMake's Android auto-detection

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(CMAKE_SYSTEM_VERSION 1)

set(CMAKE_C_COMPILER /usr/bin/clang-17)
set(CMAKE_CXX_COMPILER /usr/bin/clang++-17)

set(CMAKE_C_COMPILER_FORCED TRUE)
set(CMAKE_CXX_COMPILER_FORCED TRUE)

# Disable Android detection
set(ANDROID FALSE CACHE BOOL "Disable Android detection")
set(ANDROID_NDK_HOME "" CACHE PATH "Disable NDK detection")

# NDK sysroot - pass via CMake variable from command line
if(DEFINED ENV{ANDROID_NDK_HOME})
    set(NDK_PATH "$ENV{ANDROID_NDK_HOME}")
elseif(NDK_PATH)
    set(NDK_PATH "${NDK_PATH}")
else()
    message(FATAL_ERROR "NDK_PATH must be set via -DNDK_PATH=/path/to/ndk")
endif()

set(SYSROOT "${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/sysroot")
set(LIBCXX_ROOT "${NDK_PATH}/sources/cxx-stl/llvm-libc++")
set(NATIVE_APP_GLUE_ROOT "${NDK_PATH}/sources/android/native_app_glue")

set(CMAKE_SYSROOT "${SYSROOT}")

# Use SINGLE strings (no semicolons) - CMake treats lists as semicolon-separated
set(CMAKE_CXX_FLAGS_INIT "-nostdinc++ -isystem ${LIBCXX_ROOT}/include -isystem ${NATIVE_APP_GLUE_ROOT} -isystem ${SYSROOT}/usr/include/vulkan -isystem ${SYSROOT}/usr/include/aarch64-linux-android -target aarch64-linux-android24 --sysroot=${SYSROOT} -DANDROID -std=c++17 -fdata-sections -ffunction-sections -funwind-tables -fstack-protector-strong -no-canonical-prefixes -D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security -fuse-ld=lld")

set(CMAKE_C_FLAGS_INIT "-target aarch64-linux-android24 --sysroot=${SYSROOT} -isystem ${SYSROOT}/usr/include/aarch64-linux-android -DANDROID -fdata-sections -ffunction-sections -funwind-tables -fstack-protector-strong -no-canonical-prefixes -D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security -fuse-ld=lld")

set(CMAKE_EXE_LINKER_FLAGS_INIT "-fuse-ld=lld")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "-fuse-ld=lld")
set(CMAKE_MODULE_LINKER_FLAGS_INIT "-fuse-ld=lld")

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)