local B = {}

function B.new(warn, shade)
  local Fill = require("src.core.game3.void_fill")
  local Native = require("src.core.game3.tileset_native")
  local lg = love.graphics
  local canvas, quad, width, height, failed
  local self = {}
  function self.dispose()
    if canvas then canvas:release() end
    if quad then quad:release() end
    canvas, quad, width, height, failed = nil, nil, nil, nil, nil
  end
  function self.resolve(layout, pair)
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
  function self.draw(desc, frame, vw, vh, projection, Renderer)
    if not desc or failed == desc.key then return end
    local ok, err = pcall(allocate, desc)
    if not ok then
      self.dispose()
      failed = desc.key
      warn("void-allocation", "Void Fill backdrop allocation failed; keeping black: " .. tostring(err))
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
