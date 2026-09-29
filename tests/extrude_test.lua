local function run(ctx)
  local root = ctx.root
  local B = assert(loadfile(root .. "\\void_backdrop.lua"))()
  local checks = 0
  local function check(value, message)
    checks = checks + 1
    assert(value, message)
  end
  for _, size in ipairs({ 1, 2, 3, 7 }) do
    for _, depth in ipairs({ 1, 2, 5, 12 }) do
      local d = math.min(size, depth)
      for p = -30, size + 30 do
        local want = p < 0 and (-p - 1) % d
          or p >= size and size - 1 - (p - size) % d or p
        check(B.sample(p, size, depth) == want, "boundary-first inward tile mapping")
      end
    end
  end
  local oldLove = love
  local gpu = love and love.graphics and love.image
  local allocations, released, paints, shades = 0, 0, 0, 0
  if not gpu then
    local target, shader
    local function resource(w, h)
      return { w = w, h = h, setFilter = function() end, setWrap = function() end,
        setViewport = function() end, release = function() released = released + 1 end }
    end
    love = { graphics = {
      newCanvas = function(w, h) allocations = allocations + 1; return resource(w, h) end,
      newQuad = function() return resource() end,
      getSystemLimits = function() return { texturesize = 8192 } end,
      setCanvas = function(c) target = c end, getCanvas = function() return target end,
      setShader = function(s) shader = s end, getShader = function() return shader end,
      push = function() end, pop = function() end, origin = function() end,
      setScissor = function() end, clear = function() end, setColor = function() end,
      setBlendMode = function() end,
      draw = function() paints = paints + 1 end,
    } }
  end
  local lg = love.graphics
  local fillName, nativeName = "src.core.game3.void_fill", "src.core.game3.tileset_native"
  local oldFill, oldNative = package.loaded[fillName], package.loaded[nativeName]
  local native = { image = {}, overImage = {}, layered = true }
  local under, over, owned = {}, {}, {}
  local function own(object) owned[#owned + 1] = object; return object end
  local function pixel(mid, x, y)
    return (mid + 1) / 8, x < 8 and 0.2 or 0.8, y < 8 and 0.25 or 0.75, 1
  end
  if gpu then
    local data = own(love.image.newImageData(96, 16))
    data:mapPixel(function(x, y) return pixel(math.floor(x / 16), x % 16, y) end)
    native.image = own(lg.newImage(data))
    native.image:setFilter("nearest", "nearest")
    local overlay = own(love.image.newImageData(96, 16))
    overlay:mapPixel(function(x, y)
      if x % 16 < 4 and y < 4 then return 1, 1, 1, 1 end
      return 0, 0, 0, 0
    end)
    native.overImage = own(lg.newImage(overlay))
    native.overImage:setFilter("nearest", "nearest")
    for mid = 0, 5 do
      under[mid] = own(lg.newQuad(mid * 16, 0, 16, 16, 96, 16))
      over[mid] = under[mid]
    end
  else
    for mid = 0, 5 do under[mid], over[mid] = mid, 100 + mid end
  end
  package.loaded[fillName] = { mode = "black", normalize = function(mode) return mode end }
  package.loaded[nativeName] = { get = function() return native end,
    slotFor = function(_, mid) return mid end,
    quad = function(_, slot) return under[slot] end,
    overQuad = function(_, slot) return over[slot] end }
  local reads = 0
  local layout = { width = 3, height = 2 }
  function layout:midAt(x, y)
    check(x >= 0 and x < self.width and y >= 0 and y < self.height,
      "EXTRUDE never reads engine border or neighboring map")
    reads = reads + 1
    return x + y * self.width
  end
  local backdrop = B.new(function(_, message) error(message) end, function(w, h)
    shades = shades + 1
    if gpu then
      lg.setColor(0, 0, 0, 0.25)
      lg.rectangle("fill", 0, 0, w, h)
    end
  end)
  local desc = backdrop.resolve(layout, "fixture", "extrude", 8)
  check(desc and desc.mode == "extrude", "EXTRUDE ignores game's BLACK setting")
  check(#desc.regions == 8, "eight independent outside-only regions")
  local pixels = 0
  for _, region in ipairs(desc.regions) do
    pixels = pixels + region.w * region.h
    for _, cell in ipairs(region.cells) do
      local sx = B.sample((region.x + cell.x) / 16, 3, 8)
      local sy = B.sample((region.y + cell.y) / 16, 2, 8)
      check(cell.under == under[sx + sy * 3] and cell.over == over[sx + sy * 3],
        "each unmirrored metatile retains its native under and over layers")
    end
  end
  check(desc.pixels == pixels and pixels == 8 * 3 * 2 * 256,
    "budget counts every corner and edge texture")
  check(reads == pixels / 256, "only bounded strips are sampled")
  local frame = { x = -80, y = -80, dx = 0, dy = 0, scale = 1 }
  local output
  if gpu then
    output = own(lg.newCanvas(208, 192, { dpiscale = 1 }))
    lg.push("all")
    lg.setCanvas(output)
    lg.origin()
    lg.clear(0, 0, 0, 0)
  end
  backdrop.draw(desc, frame, 208, 192)
  check(shades == 8, "uniform native shade applied once to each assembled strip")
  if gpu then
    lg.setCanvas()
    local image = own(output:newImageData())
    for y = 0, 191 do
      for x = 0, 207 do
        local wx, wy = x - 80, y - 80
        local tx, ty = math.floor(wx / 16), math.floor(wy / 16)
        local r, g, b, a = image:getPixel(x, y)
        if tx >= 0 and tx < 3 and ty >= 0 and ty < 2 then
          check(a == 0, "GPU authored interior is untouched")
        else
          local sx, sy = B.sample(tx, 3, 8), B.sample(ty, 2, 8)
          local er, eg, eb = pixel(sx + sy * 3, wx % 16, wy % 16)
          if wx % 16 < 4 and wy % 16 < 4 then er, eg, eb = 1, 1, 1 end
          check(math.abs(r - er * 0.75) + math.abs(g - eg * 0.75)
            + math.abs(b - eb * 0.75) < 0.025 and a == 1,
            "GPU outward strip repetition, corners, layered pixels, shade and artwork orientation")
        end
      end
    end
    local Geometry = assert(loadfile(root .. "\\tilt_geometry.lua"))()
    local Tilt = require("src.render.Tilt")
    local Renderer = require("src.render.Renderer")
    local angle = Tilt.angle
    for _, degrees in ipairs({ 15, 35, 50 }) do
      Tilt.angle = math.rad(degrees)
      local projected = Geometry.project({ x = 0, y = 0, w = 48, h = 32 },
        208, 192, 0, 0, "full", 1, nil, Tilt)
      lg.setCanvas(output)
      lg.clear(0, 0, 0, 0)
      backdrop.draw(desc, projected, 208, 192, {}, Renderer)
      lg.setCanvas()
      local tiltedImage = own(output:newImageData())
      local sampled = 0
      for y = 0, 191 do
        for x = 0, 207 do
          local wx, wy = projected.worldAt(x + 0.5, y + 0.5)
          local tx, ty = math.floor(wx / 16), math.floor(wy / 16)
          local px, py = wx % 16, wy % 16
          if (tx < 0 or tx >= 3 or ty < 0 or ty >= 2)
            and ((px > 5 and px < 7) or (px > 9 and px < 14))
            and ((py > 5 and py < 7) or (py > 9 and py < 14)) then
            local sx, sy = B.sample(tx, 3, 8), B.sample(ty, 2, 8)
            local er, eg, eb = pixel(sx + sy * 3, px, py)
            local r, g, b, a = tiltedImage:getPixel(x, y)
            check(math.abs(r - er * 0.75) + math.abs(g - eg * 0.75)
              + math.abs(b - eb * 0.75) < 0.04 and a == 1,
              "GPU native perspective shader preserves eight extruded regions")
            sampled = sampled + 1
          end
        end
      end
      check(sampled > 100, "GPU Tilt checks cover substantial outside terrain")
    end
    Tilt.angle = angle
    local draw = lg.draw
    for _, filter in ipairs({ "crisp", "smooth" }) do
      for _, tilted in ipairs({ false, true }) do
        local filtered = tilted and Geometry.project({ x = 0, y = 0, w = 48, h = 32 },
          208, 192, 0, 0, "full", 1, nil, Tilt) or frame
        filtered.screenFilter = filter
        local sampled, canvases = 0, {}
        lg.draw = function(object, ...)
          local texture = object:typeOf("Mesh") and object:getTexture() or object
          if texture:typeOf("Canvas") then
            local min, mag = texture:getFilter()
            check(min == (filter == "smooth" and "linear" or "nearest") and mag == "nearest",
              "GPU backdrop filter follows SCREEN selection without smoothing enlarged pixels")
            sampled = sampled + 1
            canvases[texture] = true
          end
          return draw(object, ...)
        end
        lg.setCanvas(output)
        backdrop.draw(desc, filtered, 208, 192, {}, Renderer)
        lg.draw = draw
        check(sampled > 0, "GPU screen filter checks actual repeat textures")
        for texture in pairs(canvases) do
          local min, mag = texture:getFilter()
          check(min == "nearest" and mag == "nearest", "GPU owned backdrop filters restore after draw")
        end
      end
    end
    frame.screenFilter = nil
    lg.setCanvas()
    lg.pop()
  else
    check(allocations == 8, "allocation stays bounded regardless of visible world")
    local firstPaints = paints
    backdrop.draw(desc, frame, 208, 192)
    check(allocations == 8 and paints > firstPaints, "reuse textures but repaint live animation")
    local borrowed = {}
    local mesh = { texture = borrowed, getTexture = function(self) return self.texture end,
      setTexture = function(self, image) self.texture = image end,
      setVertices = function(_, vertices)
        check(#vertices == 4, "native Tilt mesh receives four vertices")
        for _, v in ipairs(vertices) do check(v[5] > 0, "positive perspective divisor") end
      end }
    local renderer = { tiltMesh = function() return mesh end,
      tiltShader = function() return {} end }
    local tilted = { cx = 24, cy = 16, horizon = 20,
      worldAt = function(x, y) return (x - 104) * 10000, (y - 100) * 10000 end,
      point = function(x, y) return x / 10000 + 104, y / 10000 + 100, 1 end }
    backdrop.draw(desc, tilted, 208, 192, {}, renderer)
    check(allocations == 8, "horizon footprint never increases texture allocation")
    check(mesh.texture == borrowed, "borrowed native Tilt mesh texture is restored")
  end
  check(backdrop.resolve(layout, "fixture") == nil, "GAME still respects BLACK")
  if not gpu then check(released == 16, "mode changes release all eight canvases and quads") end
  backdrop.dispose()
  for _, object in ipairs(owned) do object:release() end
  package.loaded[fillName], package.loaded[nativeName] = oldFill, oldNative
  love = oldLove
  print("EXTRUDE: " .. checks .. " checks passed" .. (gpu and " (GPU)" or " (CPU)"))
end

if not love then run({ root = assert(arg[1], "mod directory required") }) end
return run
