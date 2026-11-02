#pragma once

#include <jni.h>
#include <string>
#include <functional>

namespace odyssey::platform {

class JNIWrapper {
public:
    static JavaVM* getJavaVM();
    static JNIEnv* getJNIEnv();
    static void setJavaVM(JavaVM* vm);
    
    // Toast
    static void showToast(const char* message);
    
    // Vibration
        static void vibrate(int durationMs);
        static void vibratePattern(const long* pattern, int patternLength, int repeat);
    
    // Notifications
    static void showNotification(const char* title, const char* message, int priority = 0);
    static void cancelNotification(int id);
    static void cancelAllNotifications();
    
    // Uri handling
    static std::string getContentUri(const char* filePath);
    static bool openFileWithIntent(const char* filePath, const char* mimeType);
    
    // Utility
    static std::string getPackageName();
    static int getVersionCode();
    static std::string getVersionName();
    static std::string getDeviceModel();
    static std::string getAndroidVersion();
    static int getSdkInt();

private:
    static JavaVM* javaVM_;
};

} // namespace odyssey::platform