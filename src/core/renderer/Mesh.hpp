#pragma once

#include <cstdint>

namespace odyssey::renderer {

struct Mesh {
    uint32_t vertexCount = 0;
    uint32_t indexCount = 0;
};

} // namespace odyssey::renderer