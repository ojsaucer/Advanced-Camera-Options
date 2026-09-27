local R = {}

function R.available(Renderer)
  return Renderer:tiltShader() and Renderer:tiltMesh()
end
local function drawMesh(Renderer, image, vertices)
  local lg = love.graphics
  local mesh, shader = assert(Renderer:tiltMesh()), assert(Renderer:tiltShader())
  local texture, previousShader = mesh:getTexture(), lg.getShader()
  local ok, err = pcall(function()
    mesh:setTexture(image)
    mesh:setVertices(vertices)
    lg.setShader(shader)
    lg.draw(mesh)
  end)
  mesh:setTexture(texture)
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
  image:setFilter("linear", "linear")
  drawMesh(Renderer, image, vertices)
end

-- Ground is assembled at integer 1:1 world pixels by the adapter. Only the
-- completed texture is filtered/projected, never individual packed atlas UVs.
function R.ground(Renderer, raster, frame, captureX, captureY, captureW, captureH)
  local vertices = {}
  local b = frame.ground
  local x, y = math.max(captureX, b.x), math.max(captureY, b.y)
  local r, bottom = math.min(captureX + captureW, b.x + b.w),
    math.min(captureY + captureH, b.y + b.h)
  for i, p in ipairs({ { x, y }, { r, y }, { r, bottom }, { x, bottom } }) do
    local sx, sy, q = frame.point(p[1], p[2])
    vertices[i] = { sx, sy, (p[1] - captureX) / captureW, (p[2] - captureY) / captureH, q }
  end
  raster:setFilter("linear", "linear")
  drawMesh(Renderer, raster, vertices)
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
