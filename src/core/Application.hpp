#pragma once

#include <memory>
#include "core/platform/IPlatform.hpp"

namespace odyssey {

class Application {
public:
    Application();
    ~Application();

    bool initialize(platform::IPlatform* platform);
    void run();
    void shutdown();

    void update();
    void render();

    // Event handlers
    void onWindowResize(uint32_t width, uint32_t height);
    void onKeyEvent(int key, int action);
    void onTouchEvent(float x, float y, int action);

private:
    platform::IPlatform* platform_ = nullptr;
    bool initialized_ = false;
    bool running_ = false;

    // Game systems
    class Renderer* renderer_ = nullptr;
    class Scene* scene_ = nullptr;
    class InputManager* inputManager_ = nullptr;
};

} // namespace odyssey