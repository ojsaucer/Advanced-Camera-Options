local B = {}

-- Map tile coordinates, not pixels: repeating a strip must never mirror the
-- artwork within a metatile. Negative coordinates start with the boundary tile.
function B.sample(position, size, depth)
  depth = math.max(1, math.min(size, math.floor(depth or 1)))
  if position < 0 then return (-position - 1) % depth end
  if position >= size then return size - 1 - (position - size) % depth end
  return position
end

function B.regions(w, h, depth, periodX, periodY)
  local dx, dy = periodX or math.min(w, depth), periodY or math.min(h, depth)
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

function B.new(warn, shade, Scenery)
  local Fill = require("src.core.game3.void_fill")
  local Native = require("src.core.game3.tileset_native")
  local lg = love.graphics
  local canvas, quad, width, height, failed
  local strips, stripKey
  -- The adapter calls self.resolve() once per drawn frame with no framing of
  -- its own around it. Without this, EXTRUDE's per-cell scenery
  -- classification (and GAME's per-cell border lookup) would fully rerun
  -- every single frame regardless of whether the map, tileset or fill mode
  -- actually changed since the previous frame. Native's own quads are already
  -- frame-stable (see tileset_native.lua), so the resolved MID/quad
  -- assignment plan can be too. Only the drawn cell/MID plan is cached here;
  -- the backdrop's own assembled render canvases still lazily
  -- (re)allocate/repaint from that plan exactly as before.
  local resolveKey, resolveDesc
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
    resolveKey, resolveDesc = nil, nil
  end
  -- A walkable boundary tile (plain ground, tall grass, a path, ...) must
  -- never repeat into the void: doing so implies more walkable terrain
  -- exists past the area's own edge, which is never true. Only unrecognized
  -- scenery reaches this fallback (recognized trees/rocks/water/fences/walls
  -- are already always non-walkable), so substitute the nearest non-walkable
  -- tile found along the same boundary edge instead. An edge with no
  -- non-walkable tile anywhere (an entirely open, unfenced boundary) keeps
  -- its own tile as a last resort; there is nothing better to show.
  local function isWalkable(layout, x, y, Perm)
    if not Perm or not layout.collAt then return false end
    local ok, coll = pcall(layout.collAt, layout, x, y)
    return ok and Perm.isWalkable(coll)
  end
  local function searchRow(layout, w, sy, sx, Perm)
    for radius = 1, w do
      for _, dx in ipairs({ -radius, radius }) do
        local x = sx + dx
        if x >= 0 and x < w and not isWalkable(layout, x, sy, Perm) then
          return layout:midAt(x, sy), radius
        end
      end
    end
  end
  local function searchColumn(layout, h, sx, sy, Perm)
    for radius = 1, h do
      for _, dy in ipairs({ -radius, radius }) do
        local y = sy + dy
        if y >= 0 and y < h and not isWalkable(layout, sx, y, Perm) then
          return layout:midAt(sx, y), radius
        end
      end
    end
  end
  local function fallbackMid(layout, w, h, sx, sy, axis, Perm)
    local mid = layout:midAt(sx, sy)
    if not isWalkable(layout, sx, sy, Perm) then return mid end
    if axis == "x" then
      return (searchRow(layout, w, sy, sx, Perm)) or mid
    elseif axis == "y" then
      return (searchColumn(layout, h, sx, sy, Perm)) or mid
    end
    local rowMid, rowRadius = searchRow(layout, w, sy, sx, Perm)
    local colMid, colRadius = searchColumn(layout, h, sx, sy, Perm)
    if rowMid and (not colMid or rowRadius <= colRadius) then return rowMid end
    return colMid or mid
  end
  local function extrude(layout, pair, depth)
    local w, h = layout.width, layout.height
    depth = tonumber(depth) or 1
    if depth ~= depth or depth == math.huge or depth == -math.huge then depth = 1 end
    depth = math.max(1, math.floor(depth))
    local content = Scenery and Scenery.new(layout, pair, Fill, Native, depth)
    local regions, pixels = B.regions(w, h, depth,
      content and content.periodX, content and content.periodY)
    if content then
      -- A finite one-tile coastal completion must never repeat offshore.
      local rim = B.regions(w, h, 1)
      for _, region in ipairs(rim) do
        region.left, region.top = region.x, region.y
        region.right, region.bottom = region.x + region.w, region.y + region.h
        region.overlay = true
        regions[#regions + 1] = region
        pixels = pixels + region.w * region.h
      end
    end
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
    local okPerm, Perm = pcall(require, "src.core.CollPermissions")
    if not okPerm then Perm = nil end
    for _, region in ipairs(regions) do
      region.cells = {}
      local axis
      if not region.overlay then
        local vertInf = region.top == -math.huge or region.bottom == math.huge
        local horizInf = region.left == -math.huge or region.right == math.huge
        axis = vertInf and horizInf and "corner" or vertInf and "x" or horizInf and "y" or nil
      end
      for y = 0, region.h / 16 - 1 do
        for x = 0, region.w / 16 - 1 do
          local wx, wy = region.x / 16 + x, region.y / 16 + y
          local mid
          if region.overlay then mid = content.finish(wx, wy)
          else
            mid = content and content.sample(wx, wy)
            if mid == nil then
              local sx, sy = B.sample(wx, w, depth), B.sample(wy, h, depth)
              mid = axis and fallbackMid(layout, w, h, sx, sy, axis, Perm) or layout:midAt(sx, sy)
            end
          end
          if mid ~= nil then
            local slot = Native.slotFor(native, mid)
            region.cells[#region.cells + 1] = { x = x * 16, y = y * 16,
              under = Native.quad(native, slot),
              over = native.layered and native.overImage and Native.overQuad(native, slot) or nil }
          end
        end
      end
    end
    return { mode = "extrude", regions = regions, pixels = pixels, native = native,
      key = "extrude:" .. tostring(pair) .. ":" .. tostring(layout) .. ":" .. w .. ":" .. h
        .. ":" .. math.min(w, depth) .. ":" .. math.min(h, depth),
      allocationKey = w .. ":" .. h .. ":" .. (content and content.periodX or math.min(w, depth))
        .. ":" .. (content and content.periodY or math.min(h, depth)) .. ":" .. tostring(content ~= nil) }
  end
  local function resolveGame(layout, pair, mode)
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
  -- The map/tileset/fill-mode identity alone (never the expensive per-cell
  -- classification below it) determines whether a previous frame's resolved
  -- plan is still correct; Map.ensureMidLayout caches midLayout per map def,
  -- so tostring(layout) is stable across repeat visits to the same map, and
  -- Native.get(pair) returns the same stable quads for the life of this
  -- adapter regardless of how many times a cached plan is reused. GAME mode's
  -- key additionally folds in VoidFill.fillAt's own cheap availability probe
  -- (it already walks every border MID via hasMid before returning), so an
  -- atlas whose border tiles become available/unavailable between frames is
  -- never masked by an otherwise-unchanged (mode, pair, layout) key.
  function self.resolve(layout, pair, modeOverride, depth)
    local key
    if modeOverride == "extrude" then
      key = "extrude:" .. tostring(pair) .. ":" .. tostring(layout) .. ":" .. tostring(depth or 1)
    else
      local mode = Fill.normalize(Fill.mode)
      if mode == "black" then
        self.dispose()
        return nil
      end
      local hasMid = function(mid) return Native.hasMid(pair, mid) end
      local first = Fill.fillAt(mode, 0, 0, hasMid, Fill.primaryFor(pair))
      key = mode .. ":" .. tostring(pair) .. ":" .. tostring(layout) .. ":" .. tostring(first)
    end
    if resolveKey == key and resolveDesc then return resolveDesc end
    local desc
    if modeOverride == "extrude" then
      desc = extrude(layout, pair, depth)
    else
      desc = resolveGame(layout, pair, Fill.normalize(Fill.mode))
    end
    -- A failed resolution (size/atlas-availability) must keep retrying every
    -- frame, since the underlying cause (e.g. an atlas still loading
    -- asynchronously) can clear on a later frame without the key changing.
    if desc then resolveKey, resolveDesc = key, desc
    else resolveKey, resolveDesc = nil, nil end
    return desc
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
      if x < r and y < b and #region.cells > 0 then
        local strip = strips[i]
        lg.setCanvas(strip.canvas)
        lg.origin()
        lg.setScissor()
        lg.setShader()
        lg.setBlendMode("alpha", "alphamultiply")
        lg.clear(0, 0, 0, region.overlay and 0 or 1)
        lg.setColor(1, 1, 1, 1)
        for _, cell in ipairs(region.cells) do
          if cell.under then lg.draw(desc.native.image, cell.under, cell.x, cell.y) end
          if cell.over then lg.draw(desc.native.overImage, cell.over, cell.x, cell.y) end
        end
        if shade then
          lg.push("all")
          if region.overlay then
            for _, cell in ipairs(region.cells) do
              lg.setScissor(cell.x, cell.y, 16, 16)
              shade(region.w, region.h)
            end
          else shade(region.w, region.h) end
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
          strip.canvas:setFilter(frame.screenFilter == "crisp" and "nearest" or "linear",
            frame.screenFilter and "nearest" or "linear")
          local ok, err = pcall(function()
            mesh:setTexture(strip.canvas)
            mesh:setVertices(vertices)
            lg.setShader(shader)
            lg.draw(mesh)
          end)
          mesh:setTexture(texture)
          strip.canvas:setFilter("nearest", "nearest")
          lg.setShader(previousShader)
          if not ok then error(err, 0) end
        else
          strip.canvas:setFilter(frame.screenFilter == "smooth" and "linear" or "nearest", "nearest")
          strip.quad:setViewport((x - region.x) % region.w, (y - region.y) % region.h,
            r - x, b - y, region.w, region.h)
          local ok, err = pcall(lg.draw, strip.canvas, strip.quad, (x - left) * frame.scale,
            (y - top) * frame.scale, 0, frame.scale, frame.scale)
          strip.canvas:setFilter("nearest", "nearest")
          if not ok then error(err, 0) end
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
    canvas:setFilter(frame.screenFilter == "smooth" and "linear" or "nearest", "nearest")
    local x, y = frame.x - frame.dx / frame.scale, frame.y - frame.dy / frame.scale
    quad:setViewport(x % width, y % height, vw / frame.scale, vh / frame.scale, width, height)
    ok, err = pcall(lg.draw, canvas, quad, 0, 0, 0, frame.scale, frame.scale)
    canvas:setFilter("nearest", "nearest")
    if not ok then error(err, 0) end
  end
  return self
end

return B
