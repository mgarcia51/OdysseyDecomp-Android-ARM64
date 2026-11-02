#!/bin/bash
# build_android.sh - Android ARM64 Build using native clang-17
# Uses native clang-17 with NDK sysroot for ARM64 Android compilation
# CRITICAL: ANDROID_NDK_HOME is unset before cmake to prevent auto-detection

set -euo pipefail

# ============================================
# INSTALACIÓN AUTOMÁTICA DE DEPENDENCIAS
# ============================================

UNAME=$(uname -s)
if [[ "$UNAME" == "Linux" ]]; then
    if command -v apt-get &>/dev/null; then
        if ! command -v clang-17 &>/dev/null; then
            echo "Instalando clang-17..."
            sudo apt-get update -qq 2>/dev/null || true
            sudo apt-get install -y clang-17 2>&1 | tail -3
        fi
        if ! command -v ninja &>/dev/null; then
            echo "Instalando ninja-build..."
            sudo apt-get install -y ninja-build 2>&1 | tail -3
        fi
    fi
fi

# ============================================
# CONFIGURATION
# ============================================
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDROID_DIR="${PROJECT_ROOT}"
BUILD_DIR="${ANDROID_DIR}/build"

# NDK path - will be used later for Gradle and passed to cmake via -DNDK_PATH
NDK_PATH="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}"
if [[ -z "${NDK_PATH}" ]]; then
    echo "Error: ANDROID_NDK_HOME not set"
    exit 1
fi

# Save NDK_PATH for cmake (we'll unset ANDROID_NDK_HOME later)
SAVED_NDK_PATH="${NDK_PATH}"

# Check for ninja - use host ninja if available
NINJA_BIN=$(command -v ninja || echo "")
if [[ -z "$NINJA_BIN" ]]; then
    # Don't use NDK bundled ninja on ARM64 host (it's x86_64)
    echo "Usando ninja host: $(which ninja)"
fi

# Default values
BUILD_TYPE="Release"
ABI_FILTERS="arm64-v8a"
CLEAN_BUILD=false
VERBOSE=false
INSTALL_APK=false
RUN_APP=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --clean) CLEAN_BUILD=true; shift ;;
        --debug) BUILD_TYPE="Debug"; shift ;;
        --release) BUILD_TYPE="Release"; shift ;;
        --abi) ABI_FILTERS="$2"; shift 2 ;;
        --verbose) VERBOSE=true; shift ;;
        --install) INSTALL_APK=true; shift ;;
        --run) RUN_APP=true; shift ;;
        --help) echo "Usage: $0 [options]"; exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

ABI_CMAKE="${ABI_FILTERS}"

echo "=========================================="
echo "OdysseyDecomp Android ARM64 Build (native clang-17)"
echo "=========================================="
echo "NDK Path:        ${NDK_PATH}"
echo "Clang:           $(which clang-17)"
echo "Build Type:      ${BUILD_TYPE}"
echo "ABI:             ${ABI_FILTERS}"
echo "Build Directory: ${BUILD_DIR}"
echo "=========================================="

if [[ "${CLEAN_BUILD}" == "true" ]]; then
    rm -rf "${BUILD_DIR}"
fi

mkdir -p "${BUILD_DIR}"

# CMake configure - use custom toolchain, unset ANDROID_NDK_HOME to prevent auto-detection
echo "Configuring CMake..."
unset ANDROID_NDK_HOME
unset ANDROID_NDK_ROOT
cd "${BUILD_DIR}"
env -u ANDROID_NDK_HOME -u ANDROID_NDK_ROOT -u ANDROID_SDK_ROOT \
cmake \
    -DCMAKE_TOOLCHAIN_FILE="${ANDROID_DIR}/toolchain-android.cmake" \
    -DNDK_PATH="${SAVED_NDK_PATH}" \
    -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
    -G Ninja \
    "${ANDROID_DIR}"

# Build
echo "Building..."
cd "${BUILD_DIR}"
ninja ${VERBOSE:+-v}

# Find the built library
LIB_PATH="${BUILD_DIR}/libodyssey_main.so"
if [[ -f "${LIB_PATH}" ]]; then
    echo "Build successful! Library: ${LIB_PATH}"
    ls -lh "${LIB_PATH}"
else
    for abi in ${ABI_FILTERS//,/ }; do
        if [[ -f "${BUILD_DIR}/${abi}/libodyssey_main.so" ]]; then
            echo "Build successful! Library: ${BUILD_DIR}/${abi}/libodyssey_main.so"
            ls -lh "${BUILD_DIR}/${abi}/libodyssey_main.so"
            break
        fi
    done
fi

# Gradle build for APK - now export ANDROID_NDK_HOME so gradle can find it
export ANDROID_NDK_HOME="${NDK_PATH}"

if command -v gradle &>/dev/null || [[ -f "${ANDROID_DIR}/gradlew" ]]; then
    cd "${ANDROID_DIR}"
    GRADLE_CMD="./gradlew"
    if [[ ! -f "${GRADLE_CMD}" ]]; then GRADLE_CMD="gradle"; fi
    GRADLE_TASK="assemble${BUILD_TYPE^}"
    ${GRADLE_CMD} ${GRADLE_TASK}
    APK_PATH="${ANDROID_DIR}/app/build/outputs/apk/${BUILD_TYPE,,}/app-${BUILD_TYPE,,}.apk"
    if [[ -f "${APK_PATH}" ]]; then
        echo "APK built: ${APK_PATH}"
        ls -lh "${APK_PATH}"
        if [[ "${INSTALL_APK}" == "true" ]]; then
            adb install -r "${APK_PATH}"
            if [[ "${RUN_APP}" == "true" ]]; then
                adb shell am start -n com.odysseydecomp.game/com.odysseydecomp.game.MainActivity
            fi
        fi
    fi
fi

echo "=========================================="
echo "Build completed successfully!"
echo "=========================================="