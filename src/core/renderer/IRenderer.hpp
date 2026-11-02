#pragma once

#include <cstdint>
#include <vector>

namespace odyssey::renderer {

using TextureHandle = uint64_t;
using BufferHandle = uint64_t;
using PipelineHandle = uint64_t;

struct TextureDesc {
    uint32_t width = 0;
    uint32_t height = 0;
    uint32_t format = 0;
    const void* initialData = nullptr;
};

struct BufferDesc {
    size_t size = 0;
    uint32_t usageFlags = 0;
    const void* initialData = nullptr;
};

struct PipelineDesc {
    const char* vertexShaderPath = nullptr;
    const char* fragmentShaderPath = nullptr;
};

class Mesh;
class Material;

class IRenderer {
public:
    virtual ~IRenderer() = default;

    virtual bool initialize(void* windowHandle) = 0;
    virtual void shutdown() = 0;
    virtual void beginFrame() = 0;
    virtual void endFrame() = 0;
    virtual void drawMesh(const Mesh& mesh, const Material& material) = 0;
    virtual void submitDrawCommands() = 0;
    
    virtual TextureHandle createTexture(const TextureDesc& desc) = 0;
    virtual BufferHandle createBuffer(const BufferDesc& desc) = 0;
    virtual PipelineHandle createPipeline(const PipelineDesc& desc) = 0;
    
    virtual void setViewport(uint32_t width, uint32_t height) = 0;
    virtual void setScissor(uint32_t x, uint32_t y, uint32_t width, uint32_t height) = 0;
};

} // namespace odyssey::renderer
