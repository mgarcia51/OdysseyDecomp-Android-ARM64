#include "AndroidPlatform.hpp"
#include <android/log.h>
#include <android/input.h>
#include <android/native_window.h>
#include <android/asset_manager.h>
#include <android/native_activity.h>
#include <android_native_app_glue.h>
#include <chrono>
#include <cstring>

#define LOG_TAG "OdysseyDecomp"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, __VA_ARGS__)

// APP_CMD_* constants from android_native_app_glue.h
#define APP_CMD_INPUT_CHANGED       0
#define APP_CMD_INIT_WINDOW         1
#define APP_CMD_TERM_WINDOW         2
#define APP_CMD_WINDOW_RESIZED      3
#define APP_CMD_WINDOW_REDRAW_NEEDED 4
#define APP_CMD_CONTENT_RECT_CHANGED 5
#define APP_CMD_GAINED_FOCUS        6
#define APP_CMD_LOST_FOCUS          7
#define APP_CMD_CONFIG_CHANGED      8
#define APP_CMD_LOW_MEMORY          9
#define APP_CMD_START               10
#define APP_CMD_RESUME              11
#define APP_CMD_SAVE_STATE          12
#define APP_CMD_PAUSE               13
#define APP_CMD_STOP                14
#define APP_CMD_DESTROY             15

#define LOG_TAG "OdysseyDecomp"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, __VA_ARGS__)

namespace odyssey::platform {

static double getCurrentTimeStatic() {
    auto now = std::chrono::high_resolution_clock::now();
    auto duration = now.time_since_epoch();
    return std::chrono::duration<double>(duration).count();
}

AndroidPlatform::AndroidPlatform()
    : activity_(nullptr)
    , app_(nullptr)
    , window_(nullptr)
    , initialized_(false)
    , shouldClose_(false)
    , width_(0)
    , height_(0)
    , startTime_(getCurrentTimeStatic()) {
}

AndroidPlatform::~AndroidPlatform() {
    // Cleanup handled by Android lifecycle
}

void AndroidPlatform::init(int argc, char** argv) {
    (void)argc;
    (void)argv;
    
    LOGI("Initializing Android platform...");
    
    initialized_ = true;
    startTime_ = getCurrentTimeStatic();
    
    LOGI("Android platform initialized");
}

void AndroidPlatform::pollEvents() {
    // Events are handled through callbacks from native activity
    // This is called from the main loop
}

void AndroidPlatform::swapBuffers() {
    // Handled by Vulkan renderer via swapchain
}

void* AndroidPlatform::getNativeWindow() {
    return window_;
}

uint32_t AndroidPlatform::getWidth() const {
    return width_;
}

uint32_t AndroidPlatform::getHeight() const {
    return height_;
}

void AndroidPlatform::setWindowTitle(const char* title) {
    if (activity_ && title) {
        // Set window title via JNI
        JNIEnv* env;
        activity_->vm->AttachCurrentThread(&env, nullptr);
        
        jclass activityClass = env->GetObjectClass(activity_->clazz);
        jmethodID method = env->GetMethodID(activityClass, "setWindowTitle", "(Ljava/lang/String;)V");
        if (method) {
            jstring jTitle = env->NewStringUTF(title);
            env->CallVoidMethod(activity_->clazz, method, jTitle);
            env->DeleteLocalRef(jTitle);
        }
        
        activity_->vm->DetachCurrentThread();
    }
}

bool AndroidPlatform::shouldClose() const {
    return shouldClose_;
}

double AndroidPlatform::getTime() const {
    auto now = std::chrono::high_resolution_clock::now();
    auto duration = now.time_since_epoch();
    return std::chrono::duration<double>(duration).count() - startTime_;
}

void AndroidPlatform::setNativeActivity(ANativeActivity* activity) {
    activity_ = activity;
    LOGI("Native activity set");
}

void AndroidPlatform::setAndroidApp(struct android_app* app) {
    app_ = app;
}

void AndroidPlatform::handleCmd(int32_t cmd) {
    switch (cmd) {
        case APP_CMD_INIT_WINDOW:
            if (app_ && app_->window) {
                window_ = app_->window;
                width_ = ANativeWindow_getWidth(window_);
                height_ = ANativeWindow_getHeight(window_);
                LOGI("Window created: %ux%u", width_, height_);
            }
            break;
            
        case APP_CMD_TERM_WINDOW:
            LOGI("Window terminated");
            window_ = nullptr;
            break;
            
        case APP_CMD_DESTROY:
            LOGI("Activity destroyed");
            shouldClose_ = true;
            break;
            
        case APP_CMD_PAUSE:
            LOGI("App paused");
            break;
            
        case APP_CMD_RESUME:
            LOGI("App resumed");
            break;
            
        case APP_CMD_CONFIG_CHANGED:
            if (app_ && app_->window) {
                width_ = ANativeWindow_getWidth(app_->window);
                height_ = ANativeWindow_getHeight(app_->window);
                LOGI("Config changed: %ux%u", width_, height_);
            }
            break;
            
        case APP_CMD_SAVE_STATE:
            LOGI("Save state requested");
            break;
            
        case APP_CMD_START:
            LOGI("App started");
            break;
            
        case APP_CMD_STOP:
            LOGI("App stopped");
            break;
            
        default:
            break;
    }
}

int32_t AndroidPlatform::handleInput(AInputEvent* event) {
    int32_t type = AInputEvent_getType(event);
    
    if (type == AINPUT_EVENT_TYPE_MOTION) {
        int32_t action = AMotionEvent_getAction(event);
        int32_t actionMasked = action & AMOTION_EVENT_ACTION_MASK;
        
        switch (action & AMOTION_EVENT_ACTION_MASK) {
            case AMOTION_EVENT_ACTION_DOWN:
            case AMOTION_EVENT_ACTION_POINTER_DOWN:
                inputState_.touchDown = true;
                inputState_.touchX = AMotionEvent_getX(event, 0);
                inputState_.touchY = AMotionEvent_getY(event, 0);
                break;
                
            case AMOTION_EVENT_ACTION_UP:
            case AMOTION_EVENT_ACTION_POINTER_UP:
            case AMOTION_EVENT_ACTION_CANCEL:
                inputState_.touchDown = false;
                break;
                
            case AMOTION_EVENT_ACTION_MOVE:
                inputState_.touchX = AMotionEvent_getX(event, 0);
                inputState_.touchY = AMotionEvent_getY(event, 0);
                break;
        }
    } else if (type == AINPUT_EVENT_TYPE_KEY) {
        int32_t action = AKeyEvent_getAction(event);
        int32_t keyCode = AKeyEvent_getKeyCode(event);
        bool down = (action == AKEY_EVENT_ACTION_DOWN);
        
        switch (keyCode) {
            case AKEYCODE_BUTTON_A:
                inputState_.buttonA = down;
                break;
            case AKEYCODE_BUTTON_B:
                inputState_.buttonB = down;
                break;
            case AKEYCODE_BUTTON_X:
                inputState_.buttonX = down;
                break;
            case AKEYCODE_BUTTON_Y:
                inputState_.buttonY = down;
                break;
            case AKEYCODE_DPAD_UP:
                inputState_.dpadUp = down;
                break;
            case AKEYCODE_DPAD_DOWN:
                inputState_.dpadDown = down;
                break;
            case AKEYCODE_DPAD_LEFT:
                inputState_.dpadLeft = down;
                break;
            case AKEYCODE_DPAD_RIGHT:
                inputState_.dpadRight = down;
                break;
            case AKEYCODE_BUTTON_START:
                inputState_.buttonStart = down;
                break;
            case AKEYCODE_BUTTON_SELECT:
                inputState_.buttonSelect = down;
                break;
        }
        
        // Handle key up
        if (!down) {
            switch (keyCode) {
                case AKEYCODE_BUTTON_A: inputState_.buttonA = false; break;
                case AKEYCODE_BUTTON_B: inputState_.buttonB = false; break;
                case AKEYCODE_BUTTON_X: inputState_.buttonX = false; break;
                case AKEYCODE_BUTTON_Y: inputState_.buttonY = false; break;
                case AKEYCODE_DPAD_UP: inputState_.dpadUp = false; break;
                case AKEYCODE_DPAD_DOWN: inputState_.dpadDown = false; break;
                case AKEYCODE_DPAD_LEFT: inputState_.dpadLeft = false; break;
                case AKEYCODE_DPAD_RIGHT: inputState_.dpadRight = false; break;
                case AKEYCODE_BUTTON_START: inputState_.buttonStart = false; break;
                case AKEYCODE_BUTTON_SELECT: inputState_.buttonSelect = false; break;
            }
        }
    }
    return 0;
}

void AndroidPlatform::showToast(const char* message) {
    if (activity_ && message) {
        // Use JNI to show toast
        JNIEnv* env;
        activity_->vm->AttachCurrentThread(&env, nullptr);
        
        jclass activityClass = env->GetObjectClass(activity_->clazz);
        jmethodID toastMethod = env->GetMethodID(activityClass, "showToast", "(Ljava/lang/String;)V");
        if (toastMethod) {
            jstring jMessage = env->NewStringUTF(message);
            env->CallVoidMethod(activity_->clazz, toastMethod, jMessage);
            env->DeleteLocalRef(jMessage);
        }
        
        activity_->vm->DetachCurrentThread();
    }
}

void AndroidPlatform::vibrate(int durationMs) {
    if (activity_) {
        JNIEnv* env;
        activity_->vm->AttachCurrentThread(&env, nullptr);
        
        jclass activityClass = env->GetObjectClass(activity_->clazz);
        jmethodID vibrateMethod = env->GetMethodID(activityClass, "vibrate", "(I)V");
        if (vibrateMethod) {
            env->CallVoidMethod(activity_->clazz, vibrateMethod, durationMs);
        }
        
        activity_->vm->DetachCurrentThread();
    }
}

} // namespace odyssey::platform