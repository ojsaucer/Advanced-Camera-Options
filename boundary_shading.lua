local S = {}
local source = [[
extern vec2 mapSize;
extern vec2 worldOrigin;
extern float darkness;
extern float fadeDistance;
varying vec2 worldPosition;
#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 vertex_position) {
  worldPosition = vertex_position.xy + worldOrigin;
  return transform_projection * vertex_position;
}
#endif
#ifdef PIXEL
vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
  vec4 pixel = Texel(texture, uv) * color;
  vec2 p = worldPosition;
  // One world pixel protects primary edge samples when the completed raster is filtered.
  if (p.x >= -1.0 && p.y >= -1.0 && p.x < mapSize.x + 1.0 && p.y < mapSize.y + 1.0) return pixel;
  vec2 gap = max(max(-p, p - mapSize), vec2(0.0));
  float amount = fadeDistance > 0.0 ? clamp(length(gap) / fadeDistance, 0.0, 1.0) : 1.0;
  pixel.rgb *= 1.0 - darkness * amount;
  return pixel;
}
#endif
]]

function S.new(warn)
  local shader, failed
  local self = {}
  function self.dispose()
    if shader then shader:release(); shader = nil end
    failed = nil
  end
  function self.draw(Field, captureX, captureY, width, height, mode, darkness, distance, draw)
    if mode == "off" or darkness == 0 or failed then return draw() end
    local lg = love.graphics
    if not shader then
      local ok, value = pcall(lg.newShader, source)
      if not ok then
        failed = true
        warn("neighbor-shader", "Neighbor shading unavailable; keeping original tile colors: " .. tostring(value))
        return draw()
      end
      shader = value
    end
    shader:send("mapSize", { width, height })
    shader:send("darkness", darkness)
    shader:send("fadeDistance", mode == "gradient" and distance or 0)
    local original = lg.draw
    local function terrain(image)
      for _, batches in ipairs({ Field._nativeBatches or {}, Field._nativeOverBatches or {} }) do
        for _, batch in pairs(batches) do if image == batch then return true end end
      end
      return false
    end
    local function shaded(image, x, y, ...)
      if not terrain(image) then return original(image, x, y, ...) end
      local previous = lg.getShader()
      shader:send("worldOrigin", { captureX + (x or 0), captureY + (y or 0) })
      lg.setShader(shader)
      local ok, err = pcall(original, image, x, y, ...)
      lg.setShader(previous)
      if not ok then error(err, 0) end
    end
    lg.draw = shaded
    local ok, err = pcall(draw)
    if lg.draw == shaded then lg.draw = original end
    if not ok then error(err, 0) end
  end
  return self
end

return S
