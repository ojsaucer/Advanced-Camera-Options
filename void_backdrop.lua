local B = {}

-- Map tile coordinates, not pixels: repeating a strip must never mirror the
-- artwork within a metatile. Negative coordinates start with the boundary tile.
function B.sample(position, size, depth)
  depth = math.max(1, math.min(size, math.floor(depth or 1)))
  if position < 0 then return (-position - 1) % depth end
  if position >= size then return size - 1 - (position - size) % depth end
  return position
end

function B.regions(w, h, depth)
  local dx, dy = math.min(w, depth), math.min(h, depth)
  local regions, pixels = {}, 0
  for iy = -1, 1 do
    for ix = -1, 1 do
      if ix ~= 0 or iy ~= 0 then
        local rw, rh = ix == 0 and w or dx, iy == 0 and h or dy
        local x, y = ix < 0 and -dx or ix > 0 and w or 0,
          iy < 0 and -dy or iy > 0 and h or 0
        regions[#regions + 1] = { x = x * 16, y = y * 16, w = rw * 16, h = rh * 16,
          left = ix < 0 and -math.huge or ix > 0 and w * 16 or 0,
          right = ix < 0 and 0 or ix > 0 and math.huge or w * 16,
          top = iy < 0 and -math.huge or iy > 0 and h * 16 or 0,
          bottom = iy < 0 and 0 or iy > 0 and math.huge or h * 16 }
        pixels = pixels + rw * rh * 256
      end
    end
  end
  return regions, pixels
end

function B.new(warn, shade)
  local Fill = require("src.core.game3.void_fill")
  local Native = require("src.core.game3.tileset_native")
  local lg = love.graphics
  local canvas, quad, width, height, failed
  local strips, stripKey
  local self = {}
  function self.dispose()
    if canvas then canvas:release() end
    if quad then quad:release() end
    for _, strip in ipairs(strips or {}) do
      if strip.canvas then strip.canvas:release() end
      if strip.quad then strip.quad:release() end
    end
    strips, stripKey = nil, nil
    canvas, quad, width, height, failed = nil, nil, nil, nil, nil
  end
  local function extrude(layout, pair, depth)
    local w, h = layout.width, layout.height
    depth = tonumber(depth) or 1
    if depth ~= depth or depth == math.huge or depth == -math.huge then depth = 1 end
    depth = math.max(1, math.floor(depth))
    local regions, pixels = B.regions(w, h, depth)
    local limits = lg.getSystemLimits and lg.getSystemLimits()
    local maxSize = limits and limits.texturesize or 8192
    for _, region in ipairs(regions) do
      if region.w > maxSize or region.h > maxSize or pixels > 32 * 1024 * 1024 then
        self.dispose()
        warn("extrude-size", "Extruded strips exceed the backdrop/GPU size limit; keeping black.")
        return nil
      end
    end
    local native = Native.get(pair)
    if not native or not native.image then
      self.dispose()
      warn("extrude-tiles", "Extruded map tiles are unavailable; keeping a black backdrop.")
      return nil
    end
    for _, region in ipairs(regions) do
      region.cells = {}
      for y = 0, region.h / 16 - 1 do
        for x = 0, region.w / 16 - 1 do
          local sx = B.sample(region.x / 16 + x, w, depth)
          local sy = B.sample(region.y / 16 + y, h, depth)
          local slot = Native.slotFor(native, layout:midAt(sx, sy))
          region.cells[#region.cells + 1] = { x = x * 16, y = y * 16,
            under = Native.quad(native, slot),
            over = native.layered and native.overImage and Native.overQuad(native, slot) or nil }
        end
      end
    end
    return { mode = "extrude", regions = regions, pixels = pixels, native = native,
      key = "extrude:" .. tostring(pair) .. ":" .. tostring(layout) .. ":" .. w .. ":" .. h
        .. ":" .. math.min(w, depth) .. ":" .. math.min(h, depth),
      allocationKey = w .. ":" .. h .. ":" .. math.min(w, depth) .. ":" .. math.min(h, depth) }
  end
  function self.resolve(layout, pair, modeOverride, depth)
    if modeOverride == "extrude" then return extrude(layout, pair, depth) end
    local mode = Fill.normalize(Fill.mode)
    if mode == "black" then self.dispose(); return nil end
    local native = Native.get(pair)
    if not native or not native.image then
      self.dispose()
      warn("void-tiles", "Void Fill tiles are unavailable; keeping a black backdrop.")
      return nil
    end
    local primary = Fill.primaryFor(pair)
    local hasMid = function(mid) return Native.hasMid(pair, mid) end
    local first = Fill.fillAt(mode, 0, 0, hasMid, primary)
    local border = first ~= nil and first ~= false and Fill.borderFor(mode) or nil
    local w = border and border.w or math.max(1, layout.borderWidth or 1)
    local h = border and border.h or math.max(1, layout.borderHeight or 1)
    local limits = lg.getSystemLimits and lg.getSystemLimits()
    local maxSize = limits and limits.texturesize or 8192
    if w * h > 4096 or w * 16 > maxSize or h * 16 > maxSize then
      self.dispose()
      warn("void-size", "Void Fill border exceeds the backdrop/GPU size limit; keeping black.")
      return nil
    end
    local cells = {}
    for y = 0, h - 1 do
      for x = 0, w - 1 do
        -- Ask the engine to choose eligible TREE/WATER tiles. Its nil result
        -- means the current map's own border, including incompatible interiors.
        local mid = Fill.fillAt(mode, x, y, hasMid, primary)
        if mid == nil then mid = layout:midAt(x - w, y - h) end
        if mid ~= false then
          local slot = Native.slotFor(native, mid)
          cells[#cells + 1] = { x = x * 16, y = y * 16,
            under = Native.quad(native, slot),
            over = native.layered and native.overImage and Native.overQuad(native, slot) or nil }
        end
      end
    end
    return { w = w * 16, h = h * 16, cells = cells, native = native,
      key = mode .. ":" .. tostring(pair) .. ":" .. tostring(layout) .. ":" .. w .. ":" .. h }
  end
  local function allocate(desc)
    if canvas and width == desc.w and height == desc.h then return end
    self.dispose()
    canvas = lg.newCanvas(desc.w, desc.h, { dpiscale = 1 })
    canvas:setFilter("nearest", "nearest")
    canvas:setWrap("repeat", "repeat")
    quad = lg.newQuad(0, 0, desc.w, desc.h, desc.w, desc.h)
    width, height = desc.w, desc.h
  end
  local function allocateStrips(desc)
    if strips and stripKey == desc.allocationKey then return end
    self.dispose()
    strips = {}
    for i, region in ipairs(desc.regions) do
      local strip = {}
      strips[i] = strip
      strip.canvas = lg.newCanvas(region.w, region.h, { dpiscale = 1 })
      strip.canvas:setFilter("nearest", "nearest")
      strip.canvas:setWrap("repeat", "repeat")
      strip.quad = lg.newQuad(0, 0, region.w, region.h, region.w, region.h)
    end
    stripKey = desc.allocationKey
  end
  local function drawStrips(desc, frame, vw, vh, Renderer)
    local left, top, right, bottom
    if frame.cx then
      top = math.max(0, frame.horizon + 0.5)
      if top >= vh then return end
      left, right, bottom = math.huge, -math.huge, -math.huge
      local worldTop = math.huge
      for _, p in ipairs({ { 0, top }, { vw, top }, { vw, vh }, { 0, vh } }) do
        local x, y = frame.worldAt(p[1], p[2])
        left, right = math.min(left, x), math.max(right, x)
        worldTop, bottom = math.min(worldTop, y), math.max(bottom, y)
      end
      top = worldTop
    else
      left, top = frame.x - frame.dx / frame.scale, frame.y - frame.dy / frame.scale
      right, bottom = left + vw / frame.scale, top + vh / frame.scale
    end
    local target = lg.getCanvas()
    for i, region in ipairs(desc.regions) do
      local x, y = math.max(left, region.left), math.max(top, region.top)
      local r, b = math.min(right, region.right), math.min(bottom, region.bottom)
      if x < r and y < b then
        local strip = strips[i]
        lg.setCanvas(strip.canvas)
        lg.origin()
        lg.setScissor()
        lg.setShader()
        lg.setBlendMode("alpha", "alphamultiply")
        lg.clear(0, 0, 0, 1)
        lg.setColor(1, 1, 1, 1)
        for _, cell in ipairs(region.cells) do
          if cell.under then lg.draw(desc.native.image, cell.under, cell.x, cell.y) end
          if cell.over then lg.draw(desc.native.overImage, cell.over, cell.x, cell.y) end
        end
        if shade then
          lg.push("all")
          shade(region.w, region.h)
          lg.pop()
        end
        lg.setCanvas(target)
        lg.setBlendMode("alpha", "premultiplied")
        if frame.cx then
          -- The viewport's inverse bounding rectangle stays in front of the
          -- horizon. Clip eight world regions to it, never rasterize that area.
          local mesh, shader = assert(Renderer:tiltMesh()), assert(Renderer:tiltShader())
          local texture, previousShader = mesh:getTexture(), lg.getShader()
          local vertices = {}
          for n, p in ipairs({ { x, y }, { r, y }, { r, b }, { x, b } }) do
            local sx, sy, q = frame.point(p[1], p[2])
            vertices[n] = { sx, sy, (p[1] - region.x) / region.w,
              (p[2] - region.y) / region.h, q }
          end
          strip.canvas:setFilter("linear", "linear")
          local ok, err = pcall(function()
            mesh:setTexture(strip.canvas)
            mesh:setVertices(vertices)
            lg.setShader(shader)
            lg.draw(mesh)
          end)
          mesh:setTexture(texture)
          lg.setShader(previousShader)
          if not ok then error(err, 0) end
        else
          strip.canvas:setFilter("nearest", "nearest")
          strip.quad:setViewport((x - region.x) % region.w, (y - region.y) % region.h,
            r - x, b - y, region.w, region.h)
          lg.draw(strip.canvas, strip.quad, (x - left) * frame.scale,
            (y - top) * frame.scale, 0, frame.scale, frame.scale)
        end
      end
    end
  end
  function self.draw(desc, frame, vw, vh, projection, Renderer)
    if not desc or failed == desc.key then return end
    local ok, err = pcall(desc.mode == "extrude" and allocateStrips or allocate, desc)
    if not ok then
      self.dispose()
      failed = desc.key
      warn("void-allocation", "Void Fill backdrop allocation failed; keeping black: " .. tostring(err))
      return
    end
    if desc.mode == "extrude" then
      lg.push("all")
      ok, err = pcall(drawStrips, desc, frame, vw, vh, Renderer)
      lg.pop()
      if not ok then error(err, 0) end
      return
    end
    local target = lg.getCanvas()
    lg.setCanvas(canvas)
    lg.origin()
    lg.setScissor()
    lg.setShader()
    lg.setBlendMode("alpha", "alphamultiply")
    lg.clear(0, 0, 0, 1)
    lg.setColor(1, 1, 1, 1)
    -- Repaint the small border each frame so animated/recoloured atlas tiles
    -- remain live. Packed atlas quads are only ever rasterized at integer 1:1.
    for _, cell in ipairs(desc.cells) do
      if cell.under then lg.draw(desc.native.image, cell.under, cell.x, cell.y) end
      if cell.over then lg.draw(desc.native.overImage, cell.over, cell.x, cell.y) end
    end
    if shade then
      lg.push("all")
      shade(desc.w, desc.h)
      lg.pop()
    end
    lg.setCanvas(target)
    lg.setBlendMode("alpha", "premultiplied")
    if frame.cx then
      assert(projection and Renderer, "Tilt backdrop requires the ground projection")
      projection.background(Renderer, canvas, frame)
      return
    end
    canvas:setFilter("nearest", "nearest")
    local x, y = frame.x - frame.dx / frame.scale, frame.y - frame.dy / frame.scale
    quad:setViewport(x % width, y % height, vw / frame.scale, vh / frame.scale, width, height)
    lg.draw(canvas, quad, 0, 0, 0, frame.scale, frame.scale)
  end
  return self
end

return B
