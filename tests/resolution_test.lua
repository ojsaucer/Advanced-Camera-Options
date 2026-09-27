return function(ctx)
  local T, game, settings = ctx.T, ctx.game, ctx.settings
  local lg = love.graphics
  local Renderer = require("src.render.Renderer")
  local Session = require("src.core.game3.runtime")
  local oldRects, oldPublish = Renderer.frameRects, Renderer.setWorldOverride
  local pw, ph, output = 720, 480, nil
  Renderer.frameRects = function() return { pw = pw, ph = ph } end
  Renderer.setWorldOverride = function(self, image)
    if image then output = image end
    return oldPublish(self, image)
  end
  local function render()
    Renderer.worldActive, Renderer.worldCanvas, Renderer.worldOverride = true, ctx.sentinel, nil
    lg.setCanvas(ctx.sentinel)
    output = nil
    game:draw()
    return output
  end
  settings.mode, settings.transition, settings.framing = "full", "none", "scene"
  settings.resolution = "retro"
  T.eq(render(), nil, "Retro stays on the original world-canvas path")
  settings.resolution = "screen"
  local first = assert(render(), "screen output was not published")
  T.eq(first:getWidth(), 720, "native target uses physical viewport width")
  T.eq(first:getHeight(), 480, "native target uses physical viewport height")
  T.eq(Renderer.worldOverride, nil, "publication is scoped to game draw")
  settings.mode = "partial"
  local bounded = assert(render())
  T.eq(bounded:getWidth(), 720, "Partial also renders natively")
  settings.mode = "full"
  pw, ph = 1440, 960
  local dpi = assert(render())
  T.eq(dpi:getWidth(), 1440, "HiDPI pixel width, not logical width")
  T.eq(dpi:getHeight(), 960, "HiDPI pixel height")
  pw, ph = 360, 720
  local portrait = assert(render())
  T.eq(portrait:getWidth(), 360, "resize reallocates width")
  T.eq(portrait:getHeight(), 720, "resize reallocates height")
  pw, ph = 9000, 720
  T.eq(render(), nil, "oversized target explicitly falls back to Retro")
  pw, ph = 720, 480

  local newCanvas, attempts = lg.newCanvas, 0
  lg.newCanvas = function(w, h, ...)
    if w == 720 then attempts = attempts + 1; error("injected screen allocation failure") end
    return newCanvas(w, h, ...)
  end
  T.eq(render(), nil, "allocation failure keeps a working Retro camera")
  T.eq(render(), nil, "failed screen size is not repeatedly allocated")
  T.eq(attempts, 1, "one failed allocation attempt for unchanged dimensions")
  lg.newCanvas = newCanvas
  settings.mode = "normal"
  T.eq(render(), nil, "Normal does not publish a native override")
  settings.mode = "full"
  T.check(render() ~= nil, "Normal resets the allocation failure latch")

  local external = lg.newCanvas(20, 20)
  Renderer.worldOverride = external
  output = nil
  game:draw()
  T.eq(Renderer.worldOverride, external, "another compositor's output is not overwritten")
  Renderer.worldOverride = nil
  external:release()
  Renderer.worldActive = false
  output = nil
  game:draw()
  T.eq(output, nil, "flat/fallback path cannot claim screen-resolution output")
  settings.mode = "normal"
  render()
  settings.mode = "full"
  local allocate = lg.newCanvas
  lg.newCanvas = function(w, h, ...)
    if w == 643 then error("injected world raster allocation failure") end
    return allocate(w, h, ...)
  end
  T.eq(render(), nil, "world raster failure does not publish an incomplete image")
  T.eq(lg.getCanvas(), ctx.sentinel, "world raster failure preserves active target")
  T.eq(ctx.Field.cameraPanX, 0, "world raster failure leaves engine camera unchanged")
  lg.newCanvas = allocate
  local temporary = { draw = function() end, reset = function() end }
  ctx.Runtime.call("core.update", function() end, temporary, 0)
  ctx.Runtime.call("core.update", function() end, game, 0)
  Renderer.frameRects, Renderer.setWorldOverride = oldRects, oldPublish
  Renderer.worldCanvas, Renderer.worldActive = nil, false

  if love._staticCameraGpu then
    -- Exercise the actual final compositor, not only the high-resolution
    -- intermediate: fine stripes must survive past the small world canvas.
    local Viewport = require("src.render.GameViewport")
    local savedViewport = { rect = Viewport.rect, full = Viewport.full,
      canvas = Viewport.canvas, frameActive = Viewport.frameActive }
    local priorImage = ctx.native.image
    local stripes = love.image.newImageData(16, 16)
    stripes:mapPixel(function(x)
      if x % 2 == 0 then return 0, 1, 0, 1 end
      return 0, 0, 1, 1
    end)
    local stripedImage = lg.newImage(stripes)
    ctx.native.image = stripedImage
    Session.session.map, ctx.Field._flashMapId = "FIXTURE", "FIXTURE"
    local scene = { phase = "field", data = { maps = { FIXTURE = ctx.def, SECOND = ctx.def } },
      reset = function() end }
    local nativeWidth, nativeHeight
    scene.draw = function(self)
      Renderer:beginFrame(true)
      Renderer:beginWorldPass()
      ctx.Field.draw(self, Renderer:worldViewSize())
      if Renderer.worldOverride then
        nativeWidth, nativeHeight = Renderer.worldOverride:getDimensions()
      else nativeWidth, nativeHeight = nil, nil end
      if self.failAfterWorld then error("injected post-publication failure") end
      Renderer.worldFadeAlpha = self.fade or 0
      Renderer:endWorldPass()
      lg.clear(0, 0, 0, 0)
      lg.setColor(1, 0, 0, 1)
      lg.rectangle("fill", 10, 10, 20, 10)
      lg.setColor(1, 1, 1, 1)
      if self.engineFade then require("src.ui.game3.fade").draw() end
      Renderer:endFrame()
    end
    ctx.Runtime.call("core.update", function() end, scene, 0)
    lg.setCanvas()
    Renderer:init()
    Renderer:setUISize(240, 160)
    local function capture(resolution, dpiScale, width, height)
      local target = lg.newCanvas(width, height, { dpiscale = dpiScale })
      Viewport.canvas, Viewport.frameActive = target, true
      Viewport.rect = { x = 0, y = 0, width = width, height = height }
      Viewport.full = { width = width, height = height, dpiX = dpiScale, dpiY = dpiScale }
      settings.resolution = resolution
      ctx.Field._nativeDirty = true
      scene:draw()
      lg.setCanvas()
      local pixels = target:newImageData()
      Viewport.canvas = nil
      target:release()
      return pixels
    end
    local function changes(pixels)
      local total, previous = 0, nil
      for x = 70, 650 do
        local _, green = pixels:getPixel(x, 300)
        local value = green > 0.5
        if previous ~= nil and value ~= previous then total = total + 1 end
        previous = value
      end
      return total
    end
    settings.mode = "full"
    local retro = capture("retro", 1, 720, 480)
    T.eq(nativeWidth, nil, "GPU: Retro uses engine's normal final blit")
    local sharp = capture("screen", 1, 720, 480)
    T.eq(nativeWidth, 720, "GPU: native image reaches final compositor at 720px")
    T.eq(nativeHeight, 480, "GPU: native height reaches final compositor")
    T.check(changes(sharp) > changes(retro) * 2,
      "GPU: final screen retains >2x fine detail, not an enlarged Retro image")
    local highdpi = capture("screen", 2, 360, 240)
    T.eq(nativeWidth, 720, "GPU: 2x DPI renders physical 720px from 360 units")
    T.eq(nativeHeight, 480, "GPU: 2x DPI renders physical height")
    T.eq(changes(highdpi), changes(sharp), "GPU: HiDPI preserves the same physical detail")
    for _, image in ipairs({ retro, sharp, highdpi }) do
      local r, green, blue = image:getPixel(35, 35)
      T.check(r > 0.99 and green < 0.01 and blue < 0.01, "GPU: UI position/color unchanged")
      r, green, blue = image:getPixel(95, 35)
      T.check(r < 0.01, "GPU: UI width unchanged")
      r, green, blue = image:getPixel(0, 300)
      T.check(r < 0.01 and green < 0.01 and blue < 0.01, "GPU: whole-area margins remain black")
    end
    local tall = capture("screen", 1, 360, 720)
    T.eq(nativeWidth, 360, "GPU: compositor resize follows new width")
    T.eq(nativeHeight, 720, "GPU: compositor resize follows new height")
    retro:release(); sharp:release(); highdpi:release(); tall:release()
    scene.fade = 1
    local faded = capture("screen", 1, 720, 480)
    local r, green, blue = faded:getPixel(200, 300)
    T.check(r < 0.01 and green < 0.01 and blue < 0.01, "GPU: engine world fade still applies")
    r, green = faded:getPixel(35, 35)
    T.check(r > 0.99 and green < 0.01, "GPU: engine world fade does not darken UI")
    faded:release()
    scene.fade = nil
    assert(loadfile(ctx.root .. "\\tests\\seam_test.lua"))()({
      T = T, native = ctx.native, settings = settings, capture = capture,
    })
    assert(loadfile(ctx.root .. "\\tests\\tilt_test.lua"))()({
      T = T, root = ctx.root, native = ctx.native, settings = settings,
      capture = capture, scene = scene, setTime = ctx.setTime,
    })
    assert(loadfile(ctx.root .. "\\tests\\void_fill_test.lua"))()({
      T = T, root = ctx.root, settings = settings, capture = capture, scene = scene,
      seen = ctx.seen, setTime = ctx.setTime,
    })

    local Zoom = require("src.render.Zoom")
    local oldOffset = Zoom.offset
    local function sizedMap(width, height)
      local def, layout = {}, {}
      for k, v in pairs(ctx.def) do def[k] = v end
      for k, v in pairs(ctx.def.midLayout) do layout[k] = v end
      def.width, def.height, def.midLayout = width, height, layout
      layout.width, layout.height = width, height
      return def
    end
    local large, small = sizedMap(80, 60), sizedMap(8, 8)
    local function stripeWidths(pixels)
      local shortest, longest, start, previous = math.huge, 0, 70, nil
      for x = 70, 650 do
        local _, green = pixels:getPixel(x, 300)
        local value = green > 0.5
        if previous ~= nil and value ~= previous then
          if start ~= 70 then
            shortest, longest = math.min(shortest, x - start), math.max(longest, x - start)
          end
          start = x
        end
        previous = value
      end
      return shortest, longest
    end
    settings.mode, settings.zoom_style = "partial", "consistent"
    for _, def in ipairs({ ctx.def, large }) do
      scene.data.maps.FIXTURE = def
      for _, offset in ipairs({ 0, -1 }) do
        Zoom.offset = offset
        for _, zoom in ipairs({ 100, 200 }) do
          settings.zoom = zoom
          for _, resolution in ipairs({ "retro", "screen" }) do
            for _, view in ipairs({ { 1, 720, 480 }, { 2, 360, 240 },
              { 1, 722, 482 }, { 2, 361, 241 } }) do
              local pixels = capture(resolution, view[1], view[2], view[3])
              local lo, hi = stripeWidths(pixels)
              local expected = (3 + offset) * zoom / 100
              T.eq(lo, expected, "GPU: smallest stripe has consistent physical pixel width")
              T.eq(hi, expected, "GPU: largest stripe has consistent physical pixel width")
              local worldWidth = resolution == "screen" and view[1] * view[2] / expected
                or Renderer.worldCanvas:getWidth() / (zoom / 100)
              T.eq(ctx.seen.w, math.ceil(worldWidth) + 3,
                "GPU: exact zoom captures correct world extent plus cropped guards")
              pixels:release()
            end
          end
        end
      end
    end
    Zoom.offset, settings.zoom = 0, 100
    for _, resolution in ipairs({ "retro", "screen" }) do
      scene.data.maps.FIXTURE, settings.zoom = ctx.def, 50
      capture(resolution, 1, 720, 480):release()
      T.eq(ctx.seen.w, 483, "GPU: half zoom captures twice normal width plus guards")
      scene.data.maps.FIXTURE, settings.zoom = large, 25
      capture(resolution, 1, 720, 480):release()
      T.eq(ctx.seen.w, 963, "GPU: quarter zoom works on a sufficiently large area")
      settings.zoom = 5
      capture(resolution, 1, 720, 480):release()
      T.eq(ctx.seen.w, 1283, "GPU: minimum zoom respects map width plus cropped guards")
    end
    settings.zoom = 100
    scene.data.maps.FIXTURE = small
    for _, resolution in ipairs({ "retro", "screen" }) do
      local pixels = capture(resolution, 1, 720, 480)
      T.eq(ctx.seen.w, 131, "GPU: small area raises zoom only enough to fit width plus guards")
      T.check(ctx.seen.h <= 128, "GPU: small-area viewport stays inside height")
      for _, point in ipairs({ { 0, 0 }, { 719, 0 }, { 0, 479 }, { 719, 479 } }) do
        local r, green, blue = pixels:getPixel(point[1], point[2])
        T.check(r < 0.01 and green + blue > 0.99, "GPU: small-area corners reveal no void")
      end
      pixels:release()
    end
    settings.zoom_style, settings.zoom = "relative", 200
    for _, resolution in ipairs({ "retro", "screen" }) do
      scene.data.maps.FIXTURE = ctx.def
      capture(resolution, 1, 720, 480):release()
      T.eq(ctx.seen.w, 363, "GPU: legacy zoom preserves medium-area view plus guards")
      scene.data.maps.FIXTURE = large
      capture(resolution, 1, 720, 480):release()
      T.eq(ctx.seen.w, 723, "GPU: legacy zoom retains area-relative scaling plus guards")
    end
    Zoom.offset = oldOffset
    settings.zoom_style, settings.mode = "consistent", "full"
    scene.data.maps.FIXTURE = ctx.def

    local redPixels = love.image.newImageData(16, 16)
    redPixels:mapPixel(function() return 1, 0, 0, 1 end)
    local redImage = lg.newImage(redPixels)
    local Fade = require("src.ui.game3.fade")
    local Warp = require("src.core.game3.warp")
    local oldBusy = Warp._busy
    scene.engineFade = true
    for _, resolution in ipairs({ "retro", "screen" }) do
      for _, effect in ipairs({ "fade", "horizontal", "vertical" }) do
        Fade.clear()
        Warp._busy = false
        settings.mode = "normal"
        capture(resolution, 1, 720, 480):release()
        settings.mode, settings.transition, settings.duration = "full", effect, 1000
        Session.session.map, ctx.Field._flashMapId = "FIXTURE", "FIXTURE"
        ctx.native.image = priorImage
        ctx.setTime(40)
        capture(resolution, 1, 720, 480):release()
        Warp._busy = true
        Fade.begin(Fade.MODE.TO_BLACK, 1)
        Fade.tick(16 / 60)
        ctx.setTime(41)
        capture(resolution, 1, 720, 480):release()
        Session.session.map, ctx.Field._flashMapId = "SECOND", "SECOND"
        ctx.native.image = redImage
        Fade.begin(Fade.MODE.FROM_BLACK, 1)
        ctx.setTime(42)
        capture(resolution, 1, 720, 480):release()
        Fade.tick(8 / 60)
        ctx.setTime(42.5)
        local arrival = capture(resolution, 1, 720, 480)
        local r, green, blue = arrival:getPixel(70, 100)
        T.check(r > 0.45 and r < 0.55 and green < 0.01 and blue < 0.01,
          "GPU: engine door fade reveals destination once, without extra " .. effect)
        arrival:release()
        Fade.tick(8 / 60)
        Warp._busy = false
        ctx.setTime(43)
        local done = capture(resolution, 1, 720, 480)
        r, green = done:getPixel(70, 100)
        T.check(r > 0.99 and green < 0.01, "GPU: no delayed camera transition after door fade")
        done:release()
      end
      -- Scripted fades can hold black without an active warp or running fade.
      settings.mode = "normal"
      capture(resolution, 1, 720, 480):release()
      settings.mode, settings.transition = "full", "fade"
      Session.session.map, ctx.Field._flashMapId = "FIXTURE", "FIXTURE"
      ctx.setTime(50)
      capture(resolution, 1, 720, 480):release()
      Fade.begin(Fade.MODE.TO_BLACK, 1)
      Fade.tick(16 / 60)
      Session.session.map, ctx.Field._flashMapId = "SECOND", "SECOND"
      ctx.setTime(51)
      capture(resolution, 1, 720, 480):release()
      Fade.clear()
      ctx.setTime(51.5)
      local uncovered = capture(resolution, 1, 720, 480)
      local r, green = uncovered:getPixel(70, 100)
      T.check(r > 0.99 and green < 0.01, "GPU: held-black script cover suppresses duplicate transition")
      uncovered:release()
    end
    Fade.clear()
    Warp._busy, scene.engineFade = oldBusy, nil
    for _, effect in ipairs({ "fade", "horizontal", "vertical" }) do
      settings.mode = "normal"
      capture("screen", 1, 720, 480):release()
      settings.mode, settings.transition, settings.duration = "full", effect, 1000
      Session.session.map, ctx.Field._flashMapId = "FIXTURE", "FIXTURE"
      ctx.native.image = priorImage
      ctx.setTime(30)
      capture("screen", 1, 720, 480):release()
      Session.session.map, ctx.Field._flashMapId = "SECOND", "SECOND"
      ctx.native.image = redImage
      ctx.setTime(31)
      capture("screen", 1, 720, 480):release()
      ctx.setTime(31.5)
      local midpoint = capture("screen", 1, 720, 480)
      r, green, blue = midpoint:getPixel(70, 100)
      if effect == "fade" then
        T.check(r < 0.01 and green < 0.01 and blue < 0.01, "GPU: native fade midpoint is black")
      else
        T.check(r < 0.2 and green > 0.7, "GPU: native " .. effect .. " retains outgoing world")
        r, green = midpoint:getPixel(650, 400)
        T.check(r > 0.99 and green < 0.01, "GPU: native " .. effect .. " presents incoming world")
      end
      r, green = midpoint:getPixel(35, 35)
      T.check(r > 0.99 and green < 0.01, "GPU: native " .. effect .. " preserves UI")
      midpoint:release()
    end
    scene.failAfterWorld = true
    settings.transition = "none"
    local errorTarget = lg.newCanvas(720, 480)
    Viewport.canvas, Viewport.frameActive = errorTarget, true
    Viewport.rect = { x = 0, y = 0, width = 720, height = 480 }
    Viewport.full = { width = 720, height = 480, dpiX = 1, dpiY = 1 }
    T.raises(function() scene:draw() end, "injected post-publication failure",
      "GPU: compositor-stage error propagates")
    T.eq(Renderer.worldOverride, nil, "GPU: error clears native override before releasing it")
    lg.setCanvas()
    Viewport.canvas = nil
    errorTarget:release()
    ctx.native.image = priorImage
    ctx.Runtime.call("core.update", function() end, game, 0)
    Renderer:releaseCanvases()
    stripes:release()
    stripedImage:release()
    redPixels:release()
    redImage:release()
    for _, key in ipairs({ "rect", "full", "canvas", "frameActive" }) do
      Viewport[key] = savedViewport[key]
    end
  end
  settings.resolution, settings.mode = "retro", "full"
  Renderer.worldActive, Renderer.worldOverride = false, nil
  lg.setCanvas(ctx.sentinel)
end
