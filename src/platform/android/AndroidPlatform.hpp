#pragma once

#include "core/platform/IPlatform.hpp"
#include <android/native_activity.h>
#include <android/native_window.h>
#include <android/input.h>
#include <android/log.h>
#include <android_native_app_glue.h>

namespace odyssey::platform {

class AndroidPlatform : public IPlatform {
public:
    AndroidPlatform();
    ~AndroidPlatform() override;

    void init(int argc, char** argv) override;
    void pollEvents() override;
    void swapBuffers() override;
    void* getNativeWindow() override;
    uint32_t getWidth() const override;
    uint32_t getHeight() const override;
    void setWindowTitle(const char* title) override;
    bool shouldClose() const override;
    double getTime() const override;

    // Android-specific
    void setNativeActivity(ANativeActivity* activity);
    void setAndroidApp(android_app* app);
    void handleCmd(int32_t cmd);
    int32_t handleInput(AInputEvent* event);

    // JNI bridge
    void showToast(const char* message);
    void vibrate(int durationMs);

private:
    ANativeActivity* activity_ = nullptr;
    android_app* app_ = nullptr;
    ANativeWindow* window_ = nullptr;
    bool initialized_ = false;
    bool shouldClose_ = false;
    uint32_t width_ = 0;
    uint32_t height_ = 0;
    double startTime_ = 0.0;

    // Input state
    struct InputState {
        float touchX = 0.0f;
        float touchY = 0.0f;
        bool touchDown = false;
        float joystickX = 0.0f;
        float joystickY = 0.0f;
        bool buttonA = false;
        bool buttonB = false;
        bool buttonX = false;
        bool buttonY = false;
        bool dpadUp = false;
        bool dpadDown = false;
        bool dpadLeft = false;
        bool dpadRight = false;
        bool buttonStart = false;
        bool buttonSelect = false;
    } inputState_;

    static double getCurrentTimeStatic();
};

} // namespace odyssey::platform