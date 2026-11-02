#!/bin/bash
# OdysseyDecomp Android Build Script
# Script de instalación y compilación manual para Android NDK
# Este script debe ejecutarse localmente en la máquina del usuario

set -e

echo "=========================================="
echo "OdysseyDecomp Android Build Script"
echo "=========================================="
echo ""

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuración
ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}"
ANDROID_NDK_VERSION="25.2.9519653"
ANDROID_NDK_HOME="$ANDROID_SDK_ROOT/ndk/$ANDROID_NDK_VERSION"
ODYSSEY_PATH="/home/ubuntu/coding/OdysseyDecomp"

echo "Configuración actual:"
echo "  ANDROID_SDK_ROOT: $ANDROID_SDK_ROOT"
echo "  ANDROID_NDK_HOME: $ANDROID_NDK_HOME"
echo ""

# Paso 1: Verificar si Android SDK está instalado
check_sdk() {
    print_status "Verificando Android SDK..."
    
    if [ ! -d "$ANDROID_SDK_ROOT" ]; then
        print_warning "Android SDK no encontrado en $ANDROID_SDK_ROOT"
        print_status "Instalando SDK..."
        install_android_sdk
    else
        print_status "Android SDK encontrado"
    fi
}

# Paso 2: Instalar Android SDK Command Line Tools
install_android_sdk() {
    print_status "Instalando Android SDK Command Line Tools..."
    
    mkdir -p "$ANDROID_SDK_ROOT"
    cd /tmp
    
    # Descargar command line tools
    if [ ! -f "commandlinetools-linux-latest.zip" ]; then
        wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O commandlinetools-linux-latest.zip
    fi
    
    unzip -q commandlinetools-linux-latest.zip -d "$ANDROID_SDK_ROOT"
    mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools/latest"
    mv "$ANDROID_SDK_ROOT/cmdline-tools"/* "$ANDROID_SDK_ROOT/cmdline-tools/latest/" 2>/dev/null || true
    
    # Aceptar licencias
    echo y | "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" --licenses > /dev/null 2>&1 || true
    
    export PATH="$PATH:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin"
}

# Paso 3: Instalar NDK
install_ndk() {
    print_status "Verificando NDK $ANDROID_NDK_VERSION..."
    
    if [ ! -d "$ANDROID_NDK_HOME" ]; then
        print_status "Instalando NDK $ANDROID_NDK_VERSION..."
        "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" "ndk;$ANDROID_NDK_VERSION"
    else
        print_status "NDK ya instalado"
    fi
}

# Paso 4: Instalar dependencias de sistema
install_system_deps() {
    print_status "Verificando dependencias del sistema..."
    
    # Ubuntu/Debian
    if command -v apt-get &> /dev/null; then
        sudo apt-get update -qq
        sudo apt-get install -y cmake git openjdk-17-jdk unzip wget ninja-build
    fi
    
    # macOS
    if command -v brew &> /dev/null; then
        brew install cmake git openjdk@17 unzip wget ninja
    fi
}

# Paso 5: Configurar variables de entorno
setup_env() {
    print_status "Configurando variables de entorno..."
    
    cat >> ~/.bashrc << EOF

# OdysseyDecomp Android Build
export ANDROID_SDK_ROOT=$ANDROID_SDK_ROOT
export ANDROID_NDK_HOME=$ANDROID_NDK_HOME
export PATH=\$PATH:\$ANDROID_SDK_ROOT/cmdline-tools/latest/bin
export PATH=\$PATH:\$ANDROID_SDK_ROOT/platform-tools
EOF
    
    cat >> ~/.zshrc << EOF

# OdysseyDecomp Android Build
export ANDROID_SDK_ROOT=$ANDROID_SDK_ROOT
export ANDROID_NDK_HOME=$ANDROID_NDK_HOME
export PATH=\$PATH:\$ANDROID_SDK_ROOT/cmdline-tools/latest/bin
export PATH=\$PATH:\$ANDROID_SDK_ROOT/platform-tools
EOF
    
    print_status "Variables configuradas en ~/.bashrc y ~/.zshrc"
    print_warning "Ejecuta 'source ~/.bashrc' para aplicar cambios"
}

# Paso 6: Verificar instalación
verify_installation() {
    print_status "Verificando instalación..."
    
    echo ""
    echo "NDK Home: $ANDROID_NDK_HOME"
    ls -lh "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/clang++" 2>/dev/null && echo "✅ Clang++ encontrado" || echo "❌ Clang++ no encontrado"
    
    echo ""
    echo "CMake:"
    cmake --version 2>/dev/null && echo "✅ CMake encontrado" || echo "❌ CMake no encontrado"
    
    echo ""
    echo "Ninja:"
    ninja --version 2>/dev/null && echo "✅ Ninja encontrado" || echo "❌ Ninja no encontrado"
    
    echo ""
    echo "Java:"
    java -version 2>/dev/null && echo "✅ Java encontrado" || echo "❌ Java no encontrado"
    
    echo ""
    echo "Gradle:"
    ./gradlew --version 2>/dev/null && echo "✅ Gradle encontrado" || echo "⚠️ Gradle no inicializado (se descargará en primer build)"
}

# Paso 7: Compilar proyecto
build_project() {
    print_status "Compilando OdysseyDecomp..."
    
    cd "$ODYSSEY_PATH/android"
    
    # Build con script wrapper
    if [ -f "./build_android.sh" ]; then
        ./build_android.sh --release --verbose
    else
        print_warning "build_android.sh no encontrado, usando Gradle directamente"
        ./gradlew assembleRelease
    fi
}

# Paso 8: Instalar en dispositivo
install_device() {
    print_status "Verificando dispositivos conectados..."
    adb devices
    
    if adb devices | grep -q "device$"; then
        print_status "Dispositivo encontrado, instalando APK..."
        adb install -r "$ODYSSEY_PATH/android/app/build/outputs/apk/release/app-release.apk"
        adb shell am start -n com.odysseydecomp.game/com.odysseydecomp.game.MainActivity
    else
        print_warning "No hay dispositivos conectados. Conecta un dispositivo con 'adb devices' para instalar"
    fi
}

# Menú principal
main() {
    echo "Seleccione una opción:"
    echo "1. Instalar dependencias del sistema"
    echo "2. Instalar Android SDK y NDK"
    echo "3. Configurar variables de entorno"
    echo "4. Verificar instalación"
    echo "5. Compilar proyecto"
    echo "6. Instalar en dispositivo"
    echo "7. Ejecutar todo el setup"
    echo "8. Salir"
    echo ""
    read -p "Opción [1-8]: " option
    
    case $option in
        1)
            install_system_deps
            ;;
        2)
            check_sdk
            install_ndk
            ;;
        3)
            setup_env
            ;;
        4)
            verify_installation
            ;;
        5)
            build_project
            ;;
        6)
            install_device
            ;;
        7)
            install_system_deps
            check_sdk
            install_ndk
            setup_env
            verify_installation
            print_status "Setup completo! Ahora puedes compilar con opción 5"
            ;;
        8)
            exit 0
            ;;
        *)
            print_error "Opción inválida"
            ;;
    esac
}

# Si se ejecuta directamente
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main
fi

echo ""
echo "=========================================="
echo "Setup completo!"
echo "=========================================="
echo ""
echo "Próximos pasos:"
echo "1. source ~/.bashrc"
echo "2. cd $ODYSSEY_PATH/android"
echo "3. ./build_android.sh --release"
echo ""
echo "Para más información, lee android/README.md"
