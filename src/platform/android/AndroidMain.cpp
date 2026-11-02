#include <android_native_app_glue.h>
#include "platform/android/AndroidPlatform.hpp"
#include "core/Application.hpp"
#include <android/log.h>

static odyssey::platform::AndroidPlatform* g_platform = nullptr;

extern "C" void android_main(struct android_app* app) {
    // Create platform instance
    static odyssey::platform::AndroidPlatform platform;
    g_platform = &platform;
    
    // Set up callbacks
    app->userData = &platform;
    app->onAppCmd = [](android_app* app, int32_t cmd) {
        static_cast<odyssey::platform::AndroidPlatform*>(app->userData)->handleCmd(cmd);
    };
    app->onInputEvent = [](android_app* app, AInputEvent* event) {
        return static_cast<odyssey::platform::AndroidPlatform*>(app->userData)->handleInput(event);
    };
    
    // Initialize platform
    platform.setNativeActivity(app->activity);
    platform.setAndroidApp(app);
    platform.init(0, nullptr);
    
    // Create and run application
    odyssey::Application appInstance;
    if (!appInstance.initialize(&platform)) {
        __android_log_print(ANDROID_LOG_ERROR, "OdysseyDecomp", "Failed to initialize application");
        return;
    }
    
    // Main loop
    int events;
    android_poll_source* source;
    while (!platform.shouldClose()) {
        // Process events
        int timeout = platform.getNativeWindow() ? 0 : -1;
        while (ALooper_pollAll(timeout, nullptr, &events, (void**)&source) >= 0) {
            if (source != nullptr) {
                source->process(app, source);
            }
        }
        
        if (!platform.shouldClose()) {
            appInstance.update();
            appInstance.render();
        }
    }
    
    appInstance.shutdown();
}