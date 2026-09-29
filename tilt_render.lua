local R = {}

function R.samplingShader()
  return love.graphics.newShader([[
    uniform vec2 textureSize;
    uniform vec4 sampleBounds;
    uniform bool projected;
    varying float depthScale;
    #ifdef VERTEX
    attribute float VertexScale;
    vec4 position(mat4 transform_projection, vec4 vertex_position) {
      depthScale = projected ? VertexScale : 1.0;
      VaryingTexCoord = vec4(VertexTexCoord.xy * depthScale, 0.0, 1.0);
      return transform_projection * vertex_position;
    }
    #endif
    #ifdef PIXEL
    vec4 effect(vec4 color, Image image, vec2 tc, vec2 sc) {
      vec2 texel = tc / depthScale * textureSize;
      vec2 footprint = max(fwidth(texel), vec2(0.0001));
      // Filtering is opt-in and minification-only: never soften enlarged
      // pixels, including at fractional magnifications.
      bool minified = any(greaterThan(footprint, vec2(1.0001)));
      vec2 sampleAt = minified ? texel : floor(texel) + vec2(0.5);
      sampleAt = clamp(sampleAt, sampleBounds.xy + vec2(0.5), sampleBounds.zw - vec2(0.5));
      // Mip levels may contain neighboring terrain or shaded guard texels.
      // Use level zero at authored edges so those cannot bleed into this map.
      vec2 edge = min(texel - sampleBounds.xy, sampleBounds.zw - texel);
      if (!minified || any(lessThan(edge, footprint * 2.0))) {
        return Texel(image, sampleAt / textureSize, -1000.0) * color;
      }
      return Texel(image, sampleAt / textureSize) * color;
    }
    #endif
  ]])
end

function R.configureSampling(shader, image, projected, bounds)
  shader:send("textureSize", { image:getDimensions() })
  shader:send("projected", projected)
  shader:send("sampleBounds", bounds or { 0, 0, image:getWidth(), image:getHeight() })
end

function R.available(Renderer)
  return Renderer:tiltShader() and Renderer:tiltMesh()
end
local function drawMesh(Renderer, image, vertices, samplingShader, sampleBounds, screenFilter)
  local lg = love.graphics
  local mesh, shader = assert(Renderer:tiltMesh()), samplingShader or assert(Renderer:tiltShader())
  local texture, previousShader = mesh:getTexture(), lg.getShader()
  local min, mag, anisotropy = image:getFilter()
  local ok, err = pcall(function()
    image:setFilter(screenFilter == "crisp" and "nearest" or "linear",
      screenFilter and "nearest" or "linear")
    mesh:setTexture(image)
    mesh:setVertices(vertices)
    if samplingShader then R.configureSampling(samplingShader, image, true, sampleBounds) end
    lg.setShader(shader)
    lg.draw(mesh)
  end)
  mesh:setTexture(texture)
  image:setFilter(min, mag, anisotropy)
  lg.setShader(previousShader)
  if not ok then error(err, 0) end
end

function R.background(Renderer, image, frame)
  -- Only points below the perspective horizon belong to the ground plane.
  -- A half-pixel guard avoids the inverse projection's singularity.
  local top = math.max(0, frame.horizon + 0.5)
  if top >= frame.vh then return end
  local w, h = image:getDimensions()
  local ox, oy = math.floor(frame.cx / w) * w, math.floor(frame.cy / h) * h
  local vertices = {}
  for i, p in ipairs({ { 0, top }, { frame.vw, top },
    { frame.vw, frame.vh }, { 0, frame.vh } }) do
    local wx, wy = frame.worldAt(p[1], p[2])
    local _, _, q = frame.point(wx, wy)
    vertices[i] = { p[1], p[2], (wx - ox) / w, (wy - oy) / h, q }
  end
  drawMesh(Renderer, image, vertices, nil, nil, frame.screenFilter)
end

-- Ground is assembled at integer 1:1 world pixels by the adapter. Only the
-- completed texture is filtered/projected, never individual packed atlas UVs.
function R.ground(Renderer, raster, frame, captureX, captureY, captureW, captureH, coverage)
  local vertices = {}
  local b = coverage or frame.ground
  local x, y = math.max(captureX, b.x), math.max(captureY, b.y)
  local r, bottom = math.min(captureX + captureW, b.x + b.w),
    math.min(captureY + captureH, b.y + b.h)
  if r <= x or bottom <= y then return end
  for i, p in ipairs({ { x, y }, { r, y }, { r, bottom }, { x, bottom } }) do
    local sx, sy, q = frame.point(p[1], p[2])
    vertices[i] = { sx, sy, (p[1] - captureX) / captureW, (p[2] - captureY) / captureH, q }
  end
  drawMesh(Renderer, raster, vertices, frame.samplingShader,
    { x - captureX, y - captureY, r - captureX, bottom - captureY }, frame.screenFilter)
end

function R.actors(Tilt, Field, frame, captureX, captureY, draw)
  local lg = love.graphics
  local original, billboard, translate = Tilt.groundPoint, Field._billboard, lg.translate
  local pending
  local function project(x, y)
    assert(not pending, "Unsupported Tilt billboard: previous foot transform was not consumed")
    local sx, sy, q = frame.point(x + captureX, y + captureY)
    if not (q > 0 and q < math.huge) then sx, sy, q = -1e9, -1e9, 1 end
    sx, sy = sx / frame.scale, sy / frame.scale
    pending = { x = x, y = y, dx = sx - x, dy = sy - y, q = q, depth = lg.getStackDepth() }
    return sx, sy, q
  end
  local function billboardTranslate(x, y)
    if not pending then return translate(x, y) end
    local p = pending
    pending = nil
    -- Audited FieldView projects feet, pushes, then translates. Consume only
    -- that handoff; later sprite-local transforms remain untouched.
    assert(lg.getStackDepth() == p.depth + 1 and x == p.dx and y == p.dy,
      "Unsupported Tilt billboard transform order")
    translate(x, y)
    translate(p.x, p.y)
    lg.scale(p.q, p.q)
    translate(-p.x, -p.y)
  end
  Tilt.groundPoint, lg.translate = project, billboardTranslate
  lg.scale(frame.scale, frame.scale)
  local ok, err = pcall(draw)
  if Tilt.groundPoint == project then Tilt.groundPoint = original end
  if lg.translate == billboardTranslate then lg.translate = translate end
  Field._billboard = billboard
  if not ok then error(err, 0) end
  assert(not pending, "Unsupported Tilt billboard: missing foot transform")
end

return R
