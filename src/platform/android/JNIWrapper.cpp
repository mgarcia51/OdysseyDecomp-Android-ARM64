#include "JNIWrapper.hpp"
#include <android/log.h>
#include <mutex>

#define LOG_TAG "OdysseyDecomp_JNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, __VA_ARGS__)

namespace odyssey::platform {

static JavaVM* javaVM_ = nullptr;
static std::mutex jniMutex_;

JavaVM* JNIWrapper::getJavaVM() {
    std::lock_guard<std::mutex> lock(jniMutex_);
    return javaVM_;
}

JNIEnv* JNIWrapper::getJNIEnv() {
    std::lock_guard<std::mutex> lock(jniMutex_);
    JNIEnv* env = nullptr;
    if (javaVM_) {
        jint result = javaVM_->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6);
        if (result == JNI_EDETACHED) {
            if (javaVM_->AttachCurrentThread(&env, nullptr) != JNI_OK) {
                return nullptr;
            }
        } else if (result != JNI_OK) {
            return nullptr;
        }
    }
    return env;
}

void JNIWrapper::setJavaVM(JavaVM* vm) {
    std::lock_guard<std::mutex> lock(jniMutex_);
    javaVM_ = vm;
}

void JNIWrapper::showToast(const char* message) {
    if (!message) return;
    
    JNIEnv* env = getJNIEnv();
    if (!env) return;
    
    jclass activityClass = env->FindClass("android/app/Activity");
    if (!activityClass) return;
    
    jmethodID getApplicationContext = env->GetMethodID(activityClass, "getApplicationContext", "()Landroid/content/Context;");
    if (!getApplicationContext) return;
    
    jclass contextClass = env->FindClass("android/content/Context");
    jmethodID getSystemService = env->GetMethodID(contextClass, "getSystemService", "(Ljava/lang/String;)Ljava/lang/Object;");
    if (!getSystemService) return;
    
    jfieldID toastField = env->GetStaticFieldID(contextClass, "TOAST_SERVICE", "Ljava/lang/String;");
    jobject context = env->CallObjectMethod(nullptr, getSystemService, env->GetStaticObjectField(contextClass, toastField));
    if (!context) return;
    
    jclass toastClass = env->FindClass("android/widget/Toast");
    jmethodID makeText = env->GetStaticMethodID(toastClass, "makeText", "(Landroid/content/Context;Ljava/lang/CharSequence;I)Landroid/widget/Toast;");
    if (!makeText) return;
    
    jstring jMessage = env->NewStringUTF(message);
    jobject toast = env->CallStaticObjectMethod(toastClass, makeText, context, jMessage, 1);
    env->DeleteLocalRef(jMessage);
    
    if (toast) {
        jmethodID show = env->GetMethodID(toastClass, "show", "()V");
        env->CallVoidMethod(toast, show);
        env->DeleteLocalRef(toast);
    }
    
    env->DeleteLocalRef(toastClass);
    env->DeleteLocalRef(contextClass);
    env->DeleteLocalRef(activityClass);
}

void JNIWrapper::vibrate(int durationMs) {
    JNIEnv* env = getJNIEnv();
    if (!env) return;
    
    jclass activityClass = env->FindClass("android/app/Activity");
    if (!activityClass) return;
    
    jmethodID getSystemService = env->GetMethodID(env->FindClass("android/content/Context"), "getSystemService", "(Ljava/lang/String;)Ljava/lang/Object;");
    jfieldID vibratorField = env->GetStaticFieldID(env->FindClass("android/content/Context"), "VIBRATOR_SERVICE", "Ljava/lang/String;");
    
    jobject vibrator = env->CallObjectMethod(nullptr, getSystemService, env->GetStaticObjectField(nullptr, vibratorField));
    if (!vibrator) return;
    
    jclass vibratorClass = env->FindClass("android/os/Vibrator");
    jmethodID vibrateMethod = env->GetMethodID(vibratorClass, "vibrate", "(J)V");
    if (vibrateMethod) {
        env->CallVoidMethod(vibrator, vibrateMethod, static_cast<jlong>(durationMs));
    }
    
    env->DeleteLocalRef(vibratorClass);
    env->DeleteLocalRef(activityClass);
}

void JNIWrapper::vibratePattern(const long* pattern, int patternLength, int repeat) {
    // placeholder
}

// Static member definition
JavaVM* JNIWrapper::javaVM_ = nullptr;

} // namespace odyssey::platform