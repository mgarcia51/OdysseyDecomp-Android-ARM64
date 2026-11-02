#!/bin/bash
# build_android.sh - Build OdysseyDecomp for Android with Vulkan
# Run inside the Docker dev container

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="/workspace/OdysseyDecomp"
BUILD_DIR="${PROJECT_ROOT}/build_android"
ANDROID_ABI="arm64-v8a"
ANDROID_API=24
CMAKE_TOOLCHAIN_FILE="${ANDROID_NDK_HOME}/build/cmake/android.toolchain.cmake"
VULKAN_SDK_PATH="/usr"
NUM_JOBS=$(nproc)

# Colors
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Print banner
echo -e "${BLUE}"
cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════════════════╗
║                    OdysseyDecomp Android Port Build Script                    ║
║                         Vulkan Renderer for Android                          ║
╚═══════════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check environment
info "Checking build environment..."

# Verify required tools
for tool in cmake ninja clang cargo adb; do
    if ! command -v $tool &> /dev/null; then
        error "$tool not found in PATH"
        exit 1
    fi
done

success "All required tools found"

# Verify environment variables
for var in ANDROID_NDK_HOME VULKAN_SDK ANDROID_SDK_ROOT; do
    if [ -z "${!var}" ]; then
        error "$var not set"
        exit 1
    fi
    if [ ! -d "${!var}" ]; then
        error "$var points to non-existent directory: ${!var}"
        exit 1
    fi
done

success "Environment variables verified"

# Parse arguments
CLEAN=false
VERBOSE=false
RUN_CHECK=false
TARGET="odyssey"

while [[ $# -gt 0 ]]; do
    case $1 in
        --clean)
            CLEAN=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --check)
            RUN_CHECK=true
            shift
            ;;
        --target)
            TARGET="$2"
            shift 2
            ;;
        *)
            error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Create build directory
info "Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Configure CMake
info "Configuring CMake for Android..."

CMAKE_ARGS=(
    -DCMAKE_TOOLCHAIN_FILE="${ANDROID_NDK_HOME}/build/cmake/android.toolchain.cmake"
    -DANDROID_ABI=arm64-v8a
    -DANDROID_PLATFORM=android-24
    -DANDROID_NDK="${ANDROID_NDK_HOME}"
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_CXX_FLAGS="-O3 -flto -fvisibility=hidden -fPIC"
    -DCMAKE_C_FLAGS="-O3 -flto -fvisibility=hidden -fPIC"
    -DCMAKE_CXX_STANDARD=17
    -DANDROID_NDK="${ANDROID_NDK_HOME}"
    -DANDROID_ABI=arm64-v8a
    -DANDROID_NATIVE_API_LEVEL=24
    -DANDROID_STL=c++_shared
    -DCMAKE_CXX_STANDARD_REQUIRED=ON
    -DCMAKE_CXX_EXTENSIONS=OFF
    -DVULKAN_SDK="${VULKAN_SDK}"
    -DVULKAN_SDK_PATH="${VULKAN_SDK}"
    -DANDROID_NDK="${ANDROID_NDK_HOME}"
    -DCMAKE_TOOLCHAIN_FILE="${ANDROID_NDK_HOME}/build/cmake/android.toolchain.cmake"
    -DCMAKE_CXX_COMPILER="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin/clang++"
    -DCMAKE_C_COMPILER="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin/clang"
    -DCMAKE_CXX_COMPILER_LAUNCHER=ccache
    -DCMAKE_C_COMPILER_LAUNCHER=ccache
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
    -DBUILD_SHARED_LIBS=ON
    -DBUILD_TESTING=OFF
    -DCMAKE_CXX_STANDARD_REQUIRED=ON
    -DCMAKE_CXX_EXTENSIONS=OFF
    -DCMAKE_CXX_FLAGS="-O3 -flto -fvisibility=hidden -fPIC -fno-exceptions -fno-rtti"
    -DCMAKE_C_FLAGS="-O3 -flto -fvisibility=hidden -fPIC"
)

if [ "$VERBOSE" = true ]; then
    CMAKE_ARGS+=(-DCMAKE_VERBOSE_MAKEFILE=ON)
fi

info "Running CMake configure..."
cmake "${CMAKE_ARGS[@]}" ..

if [ $? -ne 0 ]; then
    error "CMake configure failed"
    exit 1
fi
success "CMake configure successful"

# Build
info "Building with Ninja (${NUM_JOBS} jobs)..."
if [ "$VERBOSE" = true ]; then
    ninja -j${NUM_JOBS} -v
else
    ninja -j${NUM_JOBS}
fi

if [ $? -ne 0 ]; then
    error "Build failed"
    exit 1
fi
success "Build successful!"

# Run check if requested
if [ "$RUN_CHECK" = true ]; then
    info "Running verification checks..."
    if [ -f "tools/check" ]; then
        python3 ../OdysseyDecomp/tools/check
    else
        warn "tools/check not found, skipping verification"
    fi
fi

# Find the built binary
BINARY=$(find . -name "odyssey" -type f -executable 2>/dev/null | head -1)
if [ -n "$BINARY" ]; then
    success "Binary built: $BINARY"
    ls -lh "$BINARY"
    file "$BINARY"
else
    warn "Binary not found in expected location"
fi

# Show build stats
info "Build completed successfully!"
echo ""
echo "Build artifacts:"
ls -lh "$BUILD_DIR"/odyssey* 2>/dev/null || true
echo ""
echo "Next steps:"
echo "  1. Connect Android device via USB (adb devices)"
echo "  2. Push binary: adb push $BUILD_DIR/odyssey /data/local/tmp/odyssey"
echo "  3. Run on device: adb shell /data/local/tmp/odyssey"
echo ""
echo "For APK packaging, use:"
echo "  python3 ../OdysseyDecomp/tools/build_apk.py --input $BUILD_DIR/odyssey"