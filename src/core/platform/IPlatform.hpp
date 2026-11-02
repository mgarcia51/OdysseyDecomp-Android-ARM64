#pragma once

#include <cstdint>

namespace odyssey::platform {

class IPlatform {
public:
    virtual ~IPlatform() = default;

    virtual void init(int argc, char** argv) = 0;
    virtual void pollEvents() = 0;
    virtual void swapBuffers() = 0;
    virtual void* getNativeWindow() = 0;
    virtual uint32_t getWidth() const = 0;
    virtual uint32_t getHeight() const = 0;
    virtual void setWindowTitle(const char* title) = 0;
    virtual bool shouldClose() const = 0;
    virtual double getTime() const = 0;
};

} // namespace odyssey::platform
