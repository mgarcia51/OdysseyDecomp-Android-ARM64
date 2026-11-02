# Mobile GPU Optimization Guidelines

## 1. Vulkan Memory Allocator (VMA)

### 1.1 Integration
```cpp
#include "vk_mem_alloc.h"

VmaAllocatorCreateInfo allocatorInfo{VK_NULL_HANDLE};
allocatorInfo.pAllocationCallbacks = nullptr;
allocatorInfo.vkPhysicalDevice = physicalDevice_;
allocatorInfo.vkDevice = device_;
allocatorInfo.vkInstance = instance_;
allocatorInfo.instance = instance_;
vmaCreateAllocator(&allocatorInfo, &allocator_);

void destroyAllocator() {
    vmaDestroyAllocator(allocator_);
}
```

### 1.2 Benefits
- Eliminates small heap allocations
- Pools device memory into `VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT` chunks
- Reduces memory fragmentation
- Improves allocation speed by 10-100x

### 1.3 Usage Example
```cpp
VmaAllocationCreateInfo allocInfo{};
allocInfo.usage = VMA_MEMORY_USAGE_AUTO;
allocInfo.flags = VMA_ALLOCATION_CREATE_MAPPED_BIT;

VmaAllocation allocation;
vkCreateBuffer(device_, &bufferInfo, nullptr, &buffer_);
vmaAllocateMemoryForBuffer(allocator_, buffer_, &allocInfo, &allocation, nullptr);
```

## 2. Pipeline Caching

### 2.1 Cache Generation
```cpp
VkPipelineCacheCreateInfo pipelineCacheInfo{VK_STRUCTURE_TYPE_PIPELINE_CACHE_CREATE_INFO};
VkPipelineCache pipelineCache;
vkCreatePipelineCache(device_, &pipelineCacheInfo, nullptr, &pipelineCache);

// Save cache on shutdown
std::vector<char> cacheData;
vkGetPipelineCacheData(device_, pipelineCache, &size, nullptr);
cacheData.resize(size);
vkGetPipelineCacheData(device_, pipelineCache, &size, cacheData.data());

// Save to cache directory
JNIWrapper::saveToCache("pipeline.cache", cacheData.data(), size);
```

### 2.2 Load Cache
```cpp
if (auto cacheData = JNIWrapper::loadFromCache("pipeline.cache")) {
    VkPipelineCacheCreateInfo pipelineCacheInfo{VK_STRUCTURE_TYPE_PIPELINE_CACHE_CREATE_INFO};
    pipelineCacheInfo.initialDataSize = cacheData.size();
    pipelineCacheInfo.pInitialData = cacheData.data();
    vkCreatePipelineCache(device_, &pipelineCacheInfo, nullptr, &pipelineCache);
}
```

### 2.3 Benefits
- Eliminates shader compilation stutter on app start
- Reduces startup time from seconds to milliseconds
- Cache size typically 1-10MB

## 3. Render Pass Layout Transitions

### 3.1 Problem
Explicit `vkCmdPipelineBarrier` operations between render passes cause pipeline stalls.

### 3.2 Solution
Use clear load/store ops in render pass definition:
```cpp
VkAttachmentDescription attachment{};
attachment.format = VK_FORMAT_R8G8B8A8_UNORM;
attachment.samples = VK_SAMPLE_COUNT_1_BIT;
attachment.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR; // Clear on load
attachment.storeOp = VK_ATTACHMENT_STORE_OP_STORE; // Keep after render
attachment.stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
attachment.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
```

### 3.3 Dynamic Rendering
```cpp
VkRenderingAttachmentInfo colorAttachment{VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO};
colorAttachment.imageView = imageView;
colorAttachment.imageLayout = VK_IMAGE_LAYOUT_ATTACHMENT_OPTIMAL;
colorAttachment.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR;
colorAttachment.storeOp = VK_ATTACHMENT_STORE_OP_STORE;
colorAttachment.clearValue = clearColor;

VkRenderingInfo renderingInfo{VK_STRUCTURE_TYPE_RENDERING_INFO};
renderingInfo.colorAttachmentCount = 1;
renderingInfo.pColorAttachments = &colorAttachment;

vkCmdBeginRendering(cmdBuffer, &renderingInfo);
vkCmdEndRendering(cmdBuffer);
```

Benefits: No explicit barriers required.

## 4. Dynamic Rendering (VK_KHR_dynamic_rendering)

### 4.1 Enable Extension
```cpp
VkPhysicalDeviceDynamicRenderingFeatures dynamicRenderingFeatures{};
dynamicRenderingFeatures.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DYNAMIC_RENDERING_FEATURES;
dynamicRenderingFeatures.dynamicRendering = VK_TRUE;
```

### 4.2 Benefits
- Eliminates VkRenderPass creation overhead
- Flexible rendering with different attachment setups
- Better support for TBDR GPUs (Tile-Based Deferred Renderers)

## 5. Synchronization (VK_KHR_synchronization2)

### 5.1 Enable Feature
```cpp
VkPhysicalDeviceSynchronization2Features sync2Features{};
sync2Features.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SYNCHRONIZATION_2_FEATURES;
sync2Features.synchronization2 = VK_TRUE;
```

### 5.2 Usage Example
```cpp
VkMemoryBarrier2 memBarrier{VK_STRUCTURE_TYPE_MEMORY_BARRIER_2};
memBarrier.srcStageMask = VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT;
memBarrier.srcAccessMask = VK_ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT;
memBarrier.dstStageMask = VK_PIPELINE_STAGE_2_FRAGMENT_SHADER_BIT;
memBarrier.dstAccessMask = VK_ACCESS_2_SHADER_READ_BIT;

VkDependencyInfo depInfo{VK_STRUCTURE_TYPE_DEPENDENCY_INFO};
depInfo.memoryBarrierCount = 1;
depInfo.pMemoryBarriers = &memBarrier;

vkCmdPipelineBarrier2(commandBuffer, &depInfo);
```

Benefits: Reduced pipeline bubbles compared to legacy barriers.

## 6. Texture Compression (ASTC)

### 6.1 Formats Supported
```cpp
VkFormat formats[] = {
    VK_FORMAT_ASTC_4x4_UNORM_BLOCK,
    VK_FORMAT_ASTC_5x4_UNORM_BLOCK,
    VK_FORMAT_ASTC_5x5_UNORM_BLOCK,
    VK_FORMAT_ASTC_6x5_UNORM_BLOCK,
    VK_FORMAT_ASTC_6x6_UNORM_BLOCK,
    VK_FORMAT_ASTC_8x5_UNORM_BLOCK,
    VK_FORMAT_ASTC_8x6_UNORM_BLOCK,
    VK_FORMAT_ASTC_10x5_UNORM_BLOCK,
    VK_FORMAT_ASTC_10x6_UNORM_BLOCK,
    VK_FORMAT_ASTC_10x8_UNORM_BLOCK,
    VK_FORMAT_ASTC_12x10_UNORM_BLOCK,
    VK_FORMAT_ASTC_12x12_UNORM_BLOCK
};
```

### 6.2 Benefits
- 4-8x smaller texture memory footprint vs RGBA8
- Faster GPU decode
- Hardware support on 95% of modern Android devices

## 7. Memory Budgeting

### 7.1 Query Memory Budget
```cpp
VkPhysicalDeviceMemoryProperties memProperties;
vkGetPhysicalDeviceMemoryProperties(physicalDevice_, &memProperties);

VkMemoryHeap heap = memProperties.memoryHeaps[0];
size_t memoryBudget = heap.size;
```

### 7.2 Set Memory Limits
```cpp
#define MAX_TEXTURE_MEMORY_MB 128
#define MAX_SHADER_MEMORY_MB 32
#define MAX_VERTEX_MEMORY_MB 64

size_t totalMemoryBudget = MAX_TEXTURE_MEMORY_MB + MAX_SHADER_MEMORY_MB + MAX_VERTEX_MEMORY_MB;
```

## 8. Performance Metrics

### 8.1 Target FPS per Device Tier
| Device Tier | Target FPS | Resolution |
|-------------|-----------|------------|
| Low-End     | 30 FPS    | 720p      |
| Mid-Range   | 30-45 FPS | 1080p     |
| High-End    | 60 FPS    | 1440p+    |

### 8.2 Profiling Tools
```bash
# GPU profiling
adb shell dumpsys gfxinfo com.odysseydecomp.game

# CPU profiling
adb shell top -d 5 -n 1 -m -o %CPU | grep odyssey

# Memory profiling
adb shell dumpsys meminfo com.odysseydecomp.game
```

## 9. Known Optimization Patterns

### 9.1 Frame Pacing
```cpp
// Limit FPS to prevent battery drain
std::chrono::high_resolution_clock::time_point lastFrame = ...;
auto now = std::chrono::high_resolution_clock::now();
auto delta = std::chrono::duration_cast<std::chrono::milliseconds>(now - lastFrame);
if (delta < std::chrono::milliseconds(33)) { // 30 FPS
    std::this_thread::sleep_for(std::chrono::milliseconds(33) - delta);
}
```

### 9.2 Object Pooling
```cpp
// Pre-allocate common resources
std::vector<VkBuffer> vertexBuffers;
vertexBuffers.resize(MAX_OBJECTS);
for (auto& buffer : vertexBuffers) {
    createBuffer(buffer, MAX_VERTEX_SIZE);
}
```

### 9.3 Batch Rendering
```cpp
// Batch similar materials in single draw call
std::vector<DrawCall> drawCalls;
for (auto& object : objects) {
    if (object.material == currentMaterial) {
        drawCalls.push_back(object);
    } else {
        // Submit batch and reset
    }
}
```