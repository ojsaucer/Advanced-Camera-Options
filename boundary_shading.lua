local S = {}
local amountSource = [[
extern vec2 mapSize;
extern float darkness;
extern float fadeDistance;
float shadeAmount(vec2 p) {
  // Protect primary edge samples when the terrain raster is filtered.
  if (p.x >= -1.0 && p.y >= -1.0 && p.x < mapSize.x + 1.0 && p.y < mapSize.y + 1.0) return 0.0;
  vec2 gap = max(max(-p, p - mapSize), vec2(0.0));
  float amount = fadeDistance > 0.0 ? clamp(length(gap) / fadeDistance, 0.0, 1.0) : 1.0;
  return darkness * amount;
}
]]
local source = amountSource .. [[
extern vec2 worldOrigin;
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
  pixel.rgb *= 1.0 - shadeAmount(worldPosition);
  return pixel;
}
#endif
]]
local backdropSource = amountSource .. [[
extern vec2 worldCenter;
extern vec2 screenCenter;
extern float scale;
extern vec3 perspective;
varying vec2 screenPosition;
#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 vertex_position) {
  screenPosition = vertex_position.xy;
  return transform_projection * vertex_position;
}
#endif
#ifdef PIXEL
vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
  vec2 v = screenPosition - screenCenter;
  float denominator = perspective.x + v.y * perspective.y / perspective.z;
  if (denominator <= 0.0) return vec4(0.0);
  float y = v.y / denominator;
  float x = v.x * (1.0 - y * perspective.y / perspective.z);
  return vec4(0.0, 0.0, 0.0, shadeAmount(worldCenter + vec2(x, y) / scale));
}
#endif
]]

function S.new(warn)
  local shader, failed, backdropShader, backdropFailed
  local self = {}
  function self.dispose()
    if shader then shader:release(); shader = nil end
    if backdropShader then backdropShader:release(); backdropShader = nil end
    failed, backdropFailed = nil, nil
  end
  function self.backdrop(frame, vw, vh, width, height, mode, darkness, distance)
    if mode == "off" or darkness == 0 or backdropFailed then return end
    local lg = love.graphics
    if not backdropShader then
      local ok, value = pcall(lg.newShader, backdropSource)
      if not ok then
        backdropFailed = true
        warn("backdrop-shader", "Backdrop shading unavailable; keeping original colors: " .. tostring(value))
        return
      end
      backdropShader = value
    end
    backdropShader:send("mapSize", { width, height })
    backdropShader:send("darkness", darkness)
    backdropShader:send("fadeDistance", mode == "gradient" and distance or 0)
    backdropShader:send("scale", frame.scale)
    backdropShader:send("worldCenter", { frame.cx or frame.x, frame.cy or frame.y })
    backdropShader:send("screenCenter", { frame.dx + (frame.cx and vw / 2 or 0),
      frame.dy + (frame.cx and vh / 2 or 0) })
    backdropShader:send("perspective", frame.cx
      and { math.cos(frame.angle), math.sin(frame.angle), frame.focal * vh } or { 1, 0, 1 })
    lg.push("all")
    lg.setShader(backdropShader)
    lg.setBlendMode("alpha", "alphamultiply")
    lg.setColor(1, 1, 1, 1)
    local ok, err = pcall(lg.rectangle, "fill", 0, 0, vw, vh)
    lg.pop()
    if not ok then error(err, 0) end
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
