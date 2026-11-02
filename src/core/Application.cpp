#include "Application.hpp"
#include "platform/android/AndroidPlatform.hpp"
#include <iostream>

namespace odyssey {

Application::Application()
    : platform_(nullptr)
    , initialized_(false)
    , running_(false)
    , renderer_(nullptr)
    , scene_(nullptr)
    , inputManager_(nullptr) {
}

Application::~Application() {
    shutdown();
}

bool Application::initialize(platform::IPlatform* platform) {
    if (initialized_) return true;
    
    platform_ = platform;
    
    // Initialize renderer
    // renderer_ = new renderer::VulkanRenderer();
    // if (!renderer_->initialize(platform_->getNativeWindow())) {
    //     std::cerr << "Failed to initialize renderer" << std::endl;
    //     return false;
    // }
    
    initialized_ = true;
    running_ = true;
    return true;
}

void Application::run() {
    if (!initialized_) return;
    
    running_ = true;
    while (running_) {
        update();
        render();
    }
}

void Application::shutdown() {
    running_ = false;
    
    // Cleanup
    // delete renderer_;
    // renderer_ = nullptr;
    
    initialized_ = false;
}

void Application::update() {
    // Update game logic
    // Update input, physics, game logic, etc.
}

void Application::render() {
    // Render frame
    // renderer_->beginFrame();
    // renderer_->submitDrawCommands();
    // renderer_->endFrame();
}

void Application::onWindowResize(uint32_t width, uint32_t height) {
    // Handle window resize
    // renderer_->setViewport(width, height);
}

void Application::onKeyEvent(int key, int action) {
    // Handle key events
}

void Application::onTouchEvent(float x, float y, int action) {
    // Handle touch events
}

} // namespace odyssey