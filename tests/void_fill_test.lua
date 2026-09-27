return function(ctx)
  local T, lg = ctx.T, love.graphics
  local Geometry = assert(loadfile(ctx.root .. "\\tilt_geometry.lua"))()
  local Fill = require("src.core.game3.void_fill")
  local Native = require("src.core.game3.tileset_native")
  local Tilt = require("src.render.Tilt")
  local Field = require("src.core.game3.field_view")
  local Session = require("src.core.game3.runtime")
  local FieldWeather = require("src.core.game3.field_weather")
  local Weather = require("src.core.game3.weather")
  local angle, level = Tilt.angle, Tilt.level
  for _, degrees in ipairs({ 15, 35, 50 }) do
    Tilt.angle = math.rad(degrees)
    local f = Geometry.project({ x = 0, y = 0, w = 16, h = 16 },
      720, 480, 0, 0, "full", 1, nil, Tilt)
    for _, p in ipairs({ { 0, math.max(0, f.horizon + 0.5) }, { 720, 480 }, { 360, 240 } }) do
      local wx, wy = f.worldAt(p[1], p[2])
      local sx, sy, q = f.point(wx, wy)
      T.check(q > 0 and math.abs(sx - p[1]) < 1e-5 and math.abs(sy - p[2]) < 1e-5,
        "backdrop inverse includes Full centering and stays in front of the horizon")
    end
  end
  Tilt.angle, Tilt.level = angle, level
  local saved = {}
  local function replace(t, k, v)
    local old = t[k]
    saved[#saved + 1] = function() t[k] = old end
    t[k] = v
  end
  replace(FieldWeather, "_current", Weather.NONE)
  replace(Weather, "_suspended", false)
  local colors = { { 0, 1, 0, 1 }, { 0, 0, 1, 1 }, { 1, 0, 0, 1 },
    { 1, 1, 0, 1 }, { 0, 0, 0, 1 } }
  local native, quads, pixels = { image = {} }, {}, nil
  if ctx.capture then
    pixels = love.image.newImageData(80, 16)
    pixels:mapPixel(function(x) return unpack(colors[math.floor(x / 16) + 1]) end)
    native.image = lg.newImage(pixels)
    native.image:setFilter("nearest", "nearest")
    for mid = 0, 4 do quads[mid + 1] = lg.newQuad(mid * 16, 0, 16, 16, 80, 16) end
  else
    for mid = 0, 4 do quads[mid + 1] = mid + 1 end
  end
  local available = true
  replace(Native, "get", function() return native end)
  replace(Native, "slotFor", function(_, mid) return mid end)
  replace(Native, "quad", function(_, slot) return quads[slot + 1] end)
  replace(Native, "hasMid", function(_, mid) return available and mid >= 0 and mid <= 4 end)
  replace(Fill, "mode", "map")
  replace(Fill, "_borders", {})
  replace(Fill, "layoutFor", function(id)
    return { pair = "general__fixture", borderWidth = 1, borderHeight = 1,
      borderMids = { id == Fill.SOURCES.water and 2 or 3 } }, false
  end)
  local layout = { width = 40, height = 30, borderWidth = 1, borderHeight = 1 }
  function layout:midAt(x, y)
    if x < 0 or y < 0 or x >= self.width or y >= self.height then return 1 end
    return x == 20 and y == 15 and 4 or 0
  end
  local warnings = 0
  local backdrop = assert(loadfile(ctx.root .. "\\void_backdrop.lua"))().new(function()
    warnings = warnings + 1
  end)
  for mode, mid in pairs({ map = 1, trees = 3, water = 2 }) do
    Fill.setMode(mode)
    local desc = backdrop.resolve(layout, "general__fixture")
    T.eq(desc.cells[1].under, quads[mid + 1], "game's " .. mode .. " border choice is used")
    T.eq(desc.w * desc.h, 256, "small repeat texture instead of a whole extra world")
  end
  Fill.setMode("map")
  local tiled = { borderWidth = 2, borderHeight = 2,
    midAt = function(_, x, y) return 1 + x % 2 + y % 2 end }
  local repeatBorder = backdrop.resolve(tiled, "general__fixture")
  T.eq(repeatBorder.w, 32, "multi-tile MAP border width retained")
  T.eq(repeatBorder.h, 32, "multi-tile MAP border height retained")
  T.eq(repeatBorder.cells[1].under, quads[2], "MAP repeat phase starts at world origin")
  T.eq(repeatBorder.cells[4].under, quads[4], "MAP repeat retains both axes")
  Fill.setMode("water")
  T.eq(backdrop.resolve(layout, "building__fixture").cells[1].under, quads[2],
    "incompatible primary follows engine's MAP fallback")
  available = false
  T.eq(backdrop.resolve(layout, "general__fixture").cells[1].under, quads[2],
    "unavailable water metatile follows engine's MAP fallback")
  available = true
  Fill.setMode("black")
  T.eq(backdrop.resolve(layout, "general__fixture"), nil, "engine BLACK needs no backdrop texture")
  backdrop.dispose()

  if ctx.capture then
    local settings, scene = ctx.settings, ctx.scene
    local original = scene.data.maps.FIXTURE
    local def = {}
    for k, v in pairs(original) do def[k] = v end
    def.pair, def.midLayout = "general__fixture", layout
    replace(scene.data.maps, "FIXTURE", def)
    replace(Session.session, "map", "FIXTURE")
    replace(Field, "_flashMapId", "FIXTURE")
    replace(settings, "mode", "full")
    replace(settings, "framing", "scene")
    replace(settings, "transition", "none")
    replace(settings, "duration", settings.duration)
    replace(settings, "void_fill", "black")
    replace(Tilt, "angle", 0)
    replace(Tilt, "level", 0)
    local function color(image, x, y, want, label)
      local r, g, b = image:getPixel(x, y)
      T.check(math.abs(r - want[1]) + math.abs(g - want[2]) + math.abs(b - want[3]) < 0.03, label)
    end
    for _, view in ipairs({ { "retro", 1, 720, 480 }, { "screen", 1, 720, 480 },
      { "screen", 2, 360, 240 } }) do
      Fill.setMode("water")
      settings.void_fill = "black"
      FieldWeather.setWeather(Weather.SHADE)
      local base = ctx.capture(unpack(view))
      local captureW, captureH = ctx.seen.w, ctx.seen.h
      color(base, 5, 300, colors[5], "GPU: default margins stay black despite engine Water")
      base:release()
      FieldWeather.setWeather(Weather.NONE)
      settings.void_fill = "game"
      for mode, mid in pairs({ map = 1, water = 2, trees = 3, black = 4 }) do
        Fill.setMode(mode)
        local image = ctx.capture(unpack(view))
        color(image, 5, 300, colors[mid + 1], "GPU: " .. mode .. " fills empty margin")
        color(image, 200, 300, colors[1], "GPU: authored terrain is unchanged")
        color(image, 368, 248, colors[5], "GPU: authored black tiles are not replaced")
        color(image, 35, 35, colors[3], "GPU: UI remains above the backdrop")
        T.eq(ctx.seen.w, captureW, "backdrop does not expand the camera capture")
        T.eq(ctx.seen.h, captureH, "backdrop does not alter camera framing")
        image:release()
        FieldWeather.setWeather(Weather.SHADE)
        local shaded = { colors[mid + 1][1] * 0.68, colors[mid + 1][2] * 0.68,
          colors[mid + 1][3] * 0.74 }
        for _ = 1, 2 do
          image = ctx.capture(unpack(view))
          color(image, 5, 300, shaded, "GPU: backdrop receives native shade exactly once")
          color(image, 200, 300, { 0, 0.68, 0 }, "GPU: terrain is not shaded twice")
          color(image, 368, 248, colors[5], "GPU: shading preserves authored black")
          color(image, 35, 35, colors[3], "GPU: weather does not shade UI")
          image:release()
        end
        Weather.suspend()
        image = ctx.capture(unpack(view))
        color(image, 5, 300, colors[mid + 1], "GPU: suspended weather leaves backdrop unshaded")
        color(image, 200, 300, colors[1], "GPU: suspended weather leaves terrain unshaded")
        image:release()
        Weather.resume()
        FieldWeather.setWeather(Weather.NONE)
        image = ctx.capture(unpack(view))
        color(image, 5, 300, colors[mid + 1], "GPU: removing shade restores raw backdrop")
        image:release()
      end
      Fill.setMode("water")
      def.pair = "building__fixture"
      local unsupported = ctx.capture(unpack(view))
      color(unsupported, 5, 300, colors[2], "GPU: incompatible interior uses its own MAP border")
      unsupported:release()
      def.pair = "general__fixture"
      Fill.setMode("trees")
      Tilt.angle, Tilt.level = math.rad(35), 2
      local tilted = ctx.capture(unpack(view))
      for _, p in ipairs({ { 0, 0 }, { 719, 0 }, { 0, 479 }, { 719, 479 } }) do
        color(tilted, p[1], p[2], colors[4], "GPU: unused Tilt corners receive decorative fill")
      end
      tilted:release()
      FieldWeather.setWeather(Weather.SHADE)
      for _, degrees in ipairs({ 15, 35, 50 }) do
        Tilt.angle = math.rad(degrees)
        tilted = ctx.capture(unpack(view))
        color(tilted, 719, 479, { 0.68, 0.68, 0 },
          "GPU: native backdrop shade survives Tilt projection")
        color(tilted, 35, 35, colors[3], "GPU: tilted shade leaves UI unchanged")
        tilted:release()
      end
      FieldWeather.setWeather(Weather.NONE)
      Tilt.angle, Tilt.level = 0, 0
      settings.mode = "partial"
      FieldWeather.setWeather(Weather.SHADE)
      local bounded = ctx.capture(unpack(view))
      color(bounded, 5, 300, { 0, 0.68, 0 }, "GPU: bounded terrain receives shade only once")
      bounded:release()
      FieldWeather.setWeather(Weather.NONE)
      settings.mode = "full"
    end
    local weatherDraw, repeatCalls = FieldWeather.draw, 0
    replace(FieldWeather, "draw", function(x, y, w, h)
      if w == 16 and h == 16 then repeatCalls = repeatCalls + 1 end
      return weatherDraw(x, y, w, h)
    end)
    for _, mode in ipairs({ Weather.FOG_HORIZONTAL, Weather.RAIN, Weather.RAIN_THUNDERSTORM,
      Weather.DOWNPOUR, Weather.NONE }) do
      FieldWeather.setWeather(mode)
      ctx.capture("screen", 1, 720, 480):release()
    end
    T.eq(repeatCalls, 0, "spatial weather is never tiled onto backdrop texture")
    FieldWeather.draw = weatherDraw
    FieldWeather.setWeather(Weather.NONE)
    local checker = {}
    for k, v in pairs(layout) do checker[k] = v end
    checker.borderWidth, checker.borderHeight = 2, 2
    checker.midAt = function(self, x, y)
      if x < 0 or y < 0 or x >= self.width or y >= self.height then return 1 + x % 2 + y % 2 end
      return layout:midAt(x, y)
    end
    def.midLayout = checker
    Fill.setMode("map")
    local repeatImage = ctx.capture("screen", 1, 1360, 768)
    local foreign, found = 0, {}
    for y = 0, 767 do
      for x = 0, 120 do
        local r, g, b = repeatImage:getPixel(x, y)
        if b > 0.99 and r < 0.01 and g < 0.01 then found.blue = true
        elseif r > 0.99 and b < 0.01 and g < 0.01 then found.red = true
        elseif r > 0.99 and g > 0.99 and b < 0.01 then found.yellow = true
        else foreign = foreign + 1 end
      end
    end
    T.eq(foreign, 0, "GPU: fractional-scale repeated backdrop has no atlas-neighbor leakage")
    T.check(found.blue and found.red and found.yellow, "GPU: complete two-axis border pattern repeats")
    repeatImage:release()
    local bounds = { x = 0, y = 0, w = 640, h = 480 }
    for _, degrees in ipairs({ 15, 35, 50 }) do
      Tilt.angle, Tilt.level = math.rad(degrees), 2
      for _, view in ipairs({ { "screen", 1, 720, 480 }, { "screen", 2, 360, 240 },
        { "retro", 1, 720, 480 } }) do
        local image = ctx.capture(unpack(view))
        local factor = view[1] == "retro" and 3 or 1
        local f = Geometry.project(bounds, 720 / factor, 480 / factor, 80, 96, "full", 1, nil, Tilt)
        local bad, tested = 0, 0
        for y = 100, 470, 7 do
          for x = 3, 716, 7 do
            local sx, sy = math.floor(x / factor) + 0.5, math.floor(y / factor) + 0.5
            local u, v = Geometry.inverse(sx - f.dx, sy - f.dy, f.vw, f.vh, f.angle, Tilt.FOCAL)
            local wx, wy = f.cx + u / f.scale, f.cy + v / f.scale
            if (wx < -1 or wx > 641 or wy < -1 or wy > 481)
              and wx % 16 > 1 and wx % 16 < 15 and wy % 16 > 1 and wy % 16 < 15 then
              local mid = 1 + math.floor(wx / 16) % 2 + math.floor(wy / 16) % 2
              local r, g, b = image:getPixel(x, y)
              local want = colors[mid + 1]
              if math.abs(r - want[1]) + math.abs(g - want[2]) + math.abs(b - want[3]) > 0.05 then
                bad = bad + 1
              end
              tested = tested + 1
            end
          end
        end
        T.check(tested > 50, "GPU: perspective backdrop checks exercise visible margins")
        T.eq(bad, 0, "GPU: backdrop matches inverse ground projection at " .. degrees .. " degrees")
        image:release()
      end
    end
    local tiny = {}
    for k, v in pairs(checker) do tiny[k] = v end
    tiny.width, tiny.height = 1, 1
    def.midLayout = tiny
    Tilt.angle, Tilt.level = math.rad(50), 2
    local horizonFrame = Geometry.project({ x = 0, y = 0, w = 16, h = 16 },
      720, 480, 0, 0, "full", 1, nil, Tilt)
    T.check(horizonFrame.horizon > 0, "tiny-room fixture exercises a visible horizon")
    local horizonImage = ctx.capture("screen", 1, 720, 480)
    color(horizonImage, 3, 0, colors[5], "GPU: no upside-down terrain is drawn above the horizon")
    local r, g, b = horizonImage:getPixel(3, math.ceil(horizonFrame.horizon + 20))
    T.check(r + g + b > 0.8, "GPU: repeated perspective fill continues below the horizon")
    horizonImage:release()
    Tilt.angle, Tilt.level = 0, 0
    def.midLayout = layout
    if ctx.setTime then
      Fill.setMode("map")
      settings.void_fill, settings.transition, settings.duration = "game", "horizontal", 1000
      Tilt.angle, Tilt.level = math.rad(35), 2
      local nextLayout, nextDef = {}, {}
      for k, v in pairs(layout) do nextLayout[k] = v end
      nextLayout.midAt = function(self, x, y)
        if x < 0 or y < 0 or x >= self.width or y >= self.height then return 3 end
        return 0
      end
      for k, v in pairs(def) do nextDef[k] = v end
      nextDef.midLayout = nextLayout
      replace(scene.data.maps, "SECOND", nextDef)
      ctx.setTime(30)
      FieldWeather.setWeather(Weather.SHADE)
      ctx.capture("screen", 1, 720, 480):release()
      ctx.crossing(scene, "SECOND", "east")
      Session.session.map, Field._flashMapId = "SECOND", "SECOND"
      FieldWeather.setWeather(Weather.NONE)
      ctx.setTime(31)
      ctx.capture("screen", 1, 720, 480):release()
      ctx.setTime(31.5)
      local halfway = ctx.capture("screen", 1, 720, 480)
      color(halfway, 100, 0, { 0, 0, 0.74 }, "GPU: outgoing backdrop retains its captured shade")
      color(halfway, 620, 0, colors[4], "GPU: incoming area uses its own backdrop during scroll")
      halfway:release()
      Session.session.map, Field._flashMapId = "FIXTURE", "FIXTURE"
      settings.transition = "none"
      Tilt.angle, Tilt.level = 0, 0
    end
    -- Optional backdrop allocation failure must not disable the camera.
    settings.void_fill = "black"
    ctx.capture("screen", 1, 720, 480):release()
    settings.void_fill = "game"
    Fill.setMode("map")
    local allocate, attempts = lg.newCanvas, 0
    lg.newCanvas = function(w, h, ...)
      if w == 16 and h == 16 then attempts = attempts + 1; error("injected backdrop allocation failure") end
      return allocate(w, h, ...)
    end
    for _ = 1, 2 do
      local image = ctx.capture("screen", 1, 720, 480)
      color(image, 5, 300, colors[5], "GPU: allocation failure retains black margins")
      color(image, 200, 300, colors[1], "GPU: allocation failure preserves camera terrain")
      image:release()
    end
    lg.newCanvas = allocate
    T.eq(attempts, 1, "failed backdrop is not reallocated every frame")
  end
  for i = #saved, 1, -1 do saved[i]() end
  if ctx.capture then
    ctx.capture("screen", 1, 720, 480):release()
    pixels:release()
    native.image:release()
    for _, quad in ipairs(quads) do quad:release() end
  end
end
