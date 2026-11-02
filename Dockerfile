# OdysseyDecomp Android Port - Development Environment
# Multi-stage build: base -> deps -> dev

# =============================================================================
# BASE STAGE - Ubuntu 24.04 with essential packages
# =============================================================================
FROM ubuntu:24.04 AS base

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install base packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    wget \
    unzip \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    build-essential \
    cmake \
    ninja-build \
    pkg-config \
    python3 \
    python3-pip \
    python3-venv \
    ccache \
    llvm \
    lld \
    clang \
    libssl-dev \
    libelf-dev \
    openjdk-21-jdk-headless \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# DEPS STAGE - Android NDK, Vulkan SDK, Rust, Python deps
# =============================================================================
FROM base AS deps

# Install Android NDK
ENV ANDROID_NDK_VERSION=r27b
ENV ANDROID_NDK_ROOT=/opt/android-ndk
ENV ANDROID_NDK_HOME=/opt/android-ndk
ENV PATH="${ANDROID_NDK_HOME}:${PATH}"

RUN mkdir -p /opt && cd /opt && \
    wget -q "https://dl.google.com/android/repository/android-ndk-${ANDROID_NDK_VERSION}-linux.zip" && \
    unzip -q "android-ndk-${ANDROID_NDK_VERSION}-linux.zip" && \
    mv "android-ndk-${ANDROID_NDK_VERSION}" android-ndk && \
    rm "android-ndk-${ANDROID_NDK_VERSION}-linux.zip"

# Install Vulkan SDK (using Ubuntu package instead of downloading from LunarG)
RUN apt-get update && apt-get install -y --no-install-recommends \
    vulkan-tools \
    libvulkan-dev \
    vulkan-utility-libraries-dev \
    libvulkan1 \
    && rm -rf /var/lib/apt/lists/*

ENV VULKAN_SDK="/usr"
ENV PATH="/usr/bin:${PATH}"

# Install Rust
ENV RUSTUP_HOME=/opt/rust
ENV CARGO_HOME=/opt/cargo
ENV PATH="${CARGO_HOME}/bin:${PATH}"

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable && \
    rustup target add aarch64-linux-android && \
    cargo install cargo-ndk cargo-apk

# Install Python dependencies
RUN pip3 install --no-cache-dir --break-system-packages \
    capstone \
    colorama \
    cxxfilt \
    pyelftools \
    watchdog \
    python-Levenshtein \
    toml \
    tomli \
    requests \
    pyyaml

# =============================================================================
# DEV STAGE - Development environment with source code
# =============================================================================
FROM deps AS dev

# Set up environment
ENV ANDROID_NDK_HOME=/opt/android-ndk
ENV ANDROID_NDK_ROOT=/opt/android-ndk
ENV ANDROID_NDK_VERSION=r27b
ENV VULKAN_SDK=/opt/vulkan-sdk/1.3.296.0/x86_64
ENV PATH="${ANDROID_NDK_HOME}:${VULKAN_SDK}/bin:${CARGO_HOME}/bin:${PATH}"

# Android SDK (command line tools only)
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV ANDROID_SDK_HOME=/opt/android-sdk
ENV ANDROID_HOME=/opt/android-sdk
ENV PATH="${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools:${PATH}"

RUN mkdir -p /opt/android-sdk/cmdline-tools && cd /opt/android-sdk/cmdline-tools && \
    wget -q "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" && \
    unzip -q commandlinetools-linux-*.zip && \
    mv cmdline-tools latest && \
    rm commandlinetools-linux-*.zip && \
    yes | ./latest/bin/sdkmanager --licenses && \
    ./latest/bin/sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0" "ndk;27.0.12077973" "cmake;3.22.1"

# Set up ccache
ENV CCACHE_DIR=/workspace/.ccache
ENV CCACHE_MAXSIZE=10G
RUN mkdir -p /workspace/.ccache && ccache --max-size=10G

# Create workspace
WORKDIR /workspace

# Copy source code
COPY . /workspace/OdysseyDecomp/

# Set up git safe directory
RUN git config --global --add safe.directory /workspace/OdysseyDecomp

# Default command
CMD ["/bin/bash"]