return function(ctx)
  local T = ctx.T
  local Geometry = assert(loadfile(ctx.root .. "\\tilt_geometry.lua"))()
  local Adapter = assert(loadfile(ctx.root .. "\\adapter_gen3.lua"))()
  T.check(Adapter.withinCanvasBudget(3840, 2160, 1024, 1024, false),
    "flat 4K counts only its three allocated output buffers")
  T.check(not Adapter.withinCanvasBudget(3840, 2160, 1024, 1024, true),
    "Tilt 4K plus world raster correctly requires Retro resource fallback")
  T.check(Adapter.withinCanvasBudget(240, 160, 1024, 1024, true),
    "same tilted camera world fits Retro after SCREEN budget rejection")
  local Tilt = require("src.render.Tilt")
  local originalAngle, originalLevel = Tilt.angle, Tilt.level
  local bounds = { x = 0, y = 0, w = 640, h = 480 }
  local envelope = Geometry.envelope({})
  local large = Geometry.envelope({ { width = 128, height = 192 } })
  T.eq(large.left, 64, "large actor gets measured side envelope")
  T.eq(large.top, 208, "large actor gets measured height plus jump allowance")
  T.same(Geometry.envelope({}, large), large, "cached area envelope never shrinks while walking")
  for _, degrees in ipairs({ 0, 1, 15, 23, 35, 42, 50 }) do
    Tilt.angle = math.rad(degrees)
    for _, size in ipairs({ { 240, 160 }, { 720, 480 }, { 1360, 768 }, { 360, 720 } }) do
      local vw, vh = size[1], size[2]
      for _, p in ipairs({ { 0, 0 }, { vw, 0 }, { vw, vh }, { 0, vh }, { vw / 2, vh / 2 } }) do
        local x, y = Geometry.inverse(p[1], p[2], vw, vh, Tilt.angle, Tilt.FOCAL)
        local sx, sy = Tilt.groundPoint(x + vw / 2, y + vh / 2, vw, vh)
        T.check(math.abs(sx - p[1]) < 1e-7 and math.abs(sy - p[2]) < 1e-7,
          "Tilt inverse agrees with installed engine projection")
      end
      local full = Geometry.project(bounds, vw, vh, 0, 0, "full", 2, nil, Tilt)
      local moved = Geometry.project(bounds, vw, vh, 600, 400, "full", 2, nil, Tilt)
      T.eq(full.scale, moved.scale, "Full Tilt scale remains stationary")
      T.eq(full.cx, moved.cx, "Full Tilt horizontal centre remains stationary")
      T.eq(full.cy, moved.cy, "Full Tilt vertical centre remains stationary")
      for _, p in ipairs({ { 0, 0 }, { 640, 0 }, { 640, 480 }, { 0, 480 } }) do
        local sx, sy, q = full.point(p[1], p[2])
        T.check(sx - envelope.left * full.scale * q >= -1e-7 and sx + envelope.right * full.scale * q <= vw + 1e-7
          and sy - envelope.top * full.scale * q >= -1e-7 and sy + envelope.bottom * full.scale * q <= vh + 1e-7,
          "Full projected corner and upright overhang fit")
      end
      Tilt.angle = math.rad(35)
      local room = Geometry.project({ x = 0, y = 0, w = 64, h = 64 },
        240, 160, 0, 0, "full", 1, nil, Tilt)
      T.check(room.scale > 1, "small-room Full framing is not crushed by engine capture padding")
      local bigActor = Geometry.project(bounds, 240, 160, 0, 0, "full", 1, nil, Tilt, large)
      for _, p in ipairs({ { 0, 0 }, { 640, 0 }, { 640, 480 }, { 0, 480 } }) do
        local x, y, q = bigActor.point(p[1], p[2])
        T.check(x - large.left * bigActor.scale * q >= -1e-7 and x + large.right * bigActor.scale * q <= 240 + 1e-7
          and y - large.top * bigActor.scale * q >= -1e-7 and y <= 160 + 1e-7,
          "large measured actor fits stationary area-wide envelope")
      end
      for _, zoom in ipairs({ 0.05, 0.55, 1, 2 }) do
        for _, p in ipairs({ { -9999, -9999 }, { 9999, -9999 },
          { 9999, 9999 }, { -9999, 9999 }, { 320, 240 } }) do
          local f = Geometry.project(bounds, vw, vh, p[1], p[2], "partial", zoom, 1, Tilt)
          for _, corner in ipairs(f.footprint) do
            T.check(corner[1] >= -1e-7 and corner[1] <= 640 + 1e-7
              and corner[2] >= -1e-7 and corner[2] <= 480 + 1e-7,
              "Bounded inverse-projected trapezoid stays inside all four area edges")
          end
          T.check(f.scale >= zoom, "Tilt retains requested zoom unless boundary needs more")
        end
      end
    end
  end
  Tilt.angle = math.rad(35)
  local corner = Geometry.project(bounds, 240, 160, 0, 464, "partial", 2, 1, Tilt)
  local cornerX = corner.point(8, 480)
  T.check(cornerX < 0, "documented lower-corner clipping is retained by strict Bounded Tilt")
  Tilt.angle, Tilt.level = originalAngle, originalLevel
  if not love._staticCameraGpu or not ctx.capture then return end

  local lg = love.graphics
  local Renderer = require("src.render.Renderer")
  local Player = require("src.core.game3.player")
  local oldX, oldY = Player.px, Player.py
  local oldImage, oldQuad = ctx.native.image, ctx.native.testQuad
  local oldMode, oldZoom, oldStyle = ctx.settings.mode, ctx.settings.zoom, ctx.settings.zoom_style
  local pixels = love.image.newImageData(1024, 1024)
  pixels:mapPixel(function(x, y)
    if x >= 16 and x < 32 and y >= 16 and y < 32 then return 0, 1, 0, 1 end
    return 1, 0, 1, 1
  end)
  local image = lg.newImage(pixels)
  image:setFilter("nearest", "nearest")
  local quad = lg.newQuad(16, 16, 16, 16, 1024, 1024)
  ctx.native.image, ctx.native.testQuad = image, quad
  ctx.settings.zoom, ctx.settings.zoom_style = 100, "consistent"
  local savedPoint, savedActive = Tilt.groundPoint, Tilt.active
  local savedTranslate = lg.translate
  local priorWorld = ctx.scene.world
  local far, near = { def = {} }, { def = {} }
  ctx.scene.world = { npcs = { far, near } }
  Player.px, Player.py = 320, 240
  for _, degrees in ipairs({ 0, 15, 35, 50 }) do
    Tilt.angle, Tilt.level = math.rad(degrees), 1
    for _, mode in ipairs({ "full", "partial" }) do
      ctx.settings.mode = mode
      for _, view in ipairs({ { "screen", 1, 720, 480 }, { "screen", 2, 360, 240 },
        { "retro", 1, 720, 480 } }) do
        local retro = view[1] == "retro"
        local vw, vh, outputScale = retro and 240 or 720, retro and 160 or 480, retro and 3 or 1
        local f = Geometry.project(bounds, vw, vh, Player.px, Player.py, mode, 1,
          mode == "partial" and (retro and 1 or require("src.render.Zoom").scale(3)) or nil, Tilt)
        local depths = { 0.45, 0.85 }
        for i, npc in ipairs({ far, near }) do
          local x, y = f.worldAt(vw * 0.65, vh * depths[i])
          npc.px, npc.py = x - 8, y - 16
        end
        local output = ctx.capture(unpack(view))
        local heights = {}
        for i, npc in ipairs({ far, near }) do
          local fx, fy, q = f.point(npc.px + 8, npc.py + 16)
          fx, fy = fx * outputScale, fy * outputScale
          local s = f.scale * q * outputScale
          local top, bottom = 480, -1
          for y = math.max(0, math.floor(fy - 20 * s - 5)), math.min(479, math.ceil(fy + 5)) do
            local r, g, b = output:getPixel(math.floor(fx), y)
            if b > 0.8 and r < 0.4 and g < 0.65 then
              top, bottom = math.min(top, y), math.max(bottom, y)
            end
          end
          local tolerance = retro and 4 or 2
          T.check(bottom >= top and math.abs(bottom - top + 1 - 12 * s) <= tolerance,
            "GPU: NPC height equals camera scale times perspective depth")
          T.check(math.abs(bottom + 1 - (fy - 2 * s)) <= tolerance,
            "GPU: distance-scaled NPC keeps its foot anchor")
          heights[i] = bottom - top + 1
        end
        if degrees >= 35 then
          T.check(heights[2] > heights[1], "GPU: nearer NPC is visibly taller than distant NPC")
        end
        T.eq(lg.translate, savedTranslate, "GPU: actor pass restores graphics translation")
        output:release()
      end
    end
  end
  ctx.scene.world = priorWorld
  for _, degrees in ipairs({ 15, 35, 50 }) do
    Tilt.angle, Tilt.level = math.rad(degrees), 1
    for _, mode in ipairs({ "full", "partial" }) do
      ctx.settings.mode = mode
      for _, view in ipairs({ { "screen", 1, 720, 480 }, { "screen", 2, 360, 240 },
        { "retro", 1, 720, 480 } }) do
        for _, p in ipairs({ { 0, 0 }, { 624, 0 }, { 624, 464 }, { 0, 464 }, { 320, 240 } }) do
          Player.px, Player.py = p[1], p[2]
          local output = ctx.capture(unpack(view))
          T.eq(Tilt.groundPoint, savedPoint, "GPU: camera restores foot projection")
          T.eq(Tilt.active, savedActive, "GPU: camera restores Tilt preference gate")
          T.eq(Tilt.angle, math.rad(degrees), "GPU: camera does not mutate saved/live Tilt angle")
          local width, height = output:getDimensions()
          local bad, green = 0, 0
          for y = 130, height - 1, 5 do
            for x = 0, width - 1, 5 do
              local r, g, b = output:getPixel(x, y)
              if r > 0.7 and b > 0.7 then bad = bad + 1 end
              if g > 0.8 and r < 0.1 and b < 0.1 then green = green + 1 end
            end
          end
          T.eq(bad, 0, "GPU: Tilt ground never samples neighboring packed atlas cell")
          T.check(green > 20, "GPU: actual tilted ground is visible")
          if mode == "partial" then
            for _, q in ipairs({ { 1, 130 }, { width - 2, 130 },
              { 1, height - 2 }, { width - 2, height - 2 } }) do
              local r, g, b = output:getPixel(q[1], q[2])
              T.check(g > 0.7 and r < 0.2 and b < 0.2,
                "GPU: Bounded Tilt viewport edges contain current-map ground")
            end
            if p[1] == 320 and view[1] == "screen" then
              local Zoom = require("src.render.Zoom")
              local f = Geometry.project(bounds, width, height, p[1], p[2], mode, 1,
                Zoom.scale(3), Tilt)
              local fx, fy, q = f.point(Player.px + 8, Player.py + 16)
              local top, bottom = height, -1
              for y = math.max(0, math.floor(fy - 20 * f.scale)), math.min(height - 1, math.ceil(fy)) do
                local r, g, b = output:getPixel(math.floor(fx), y)
                if r > 0.7 and g < 0.4 and b < 0.4 then
                  top, bottom = math.min(top, y), math.max(bottom, y)
                end
              end
              T.check(math.abs(bottom - top + 1 - 12 * f.scale * q) <= 2,
                "GPU: upright actor height follows ground perspective "
                  .. string.format("(got=%s expected=%s foot=%.2f,%.2f angle=%s)",
                    bottom - top + 1, 12 * f.scale * q, fx, fy, degrees))
            end
          elseif view[1] == "screen" then
            local f = Geometry.project(bounds, width, height, p[1], p[2], mode, 1, nil, Tilt)
            for _, q in ipairs({ { 2, 2 }, { 638, 2 }, { 638, 478 }, { 2, 478 } }) do
              local x, y = f.point(q[1], q[2])
              local r, g = output:getPixel(math.floor(x), math.floor(y))
              T.check(g > 0.6 or r > 0.6, "GPU: Full Tilt retains each projected area corner")
            end
            local fx, fy, q = f.point(Player.px + 8, Player.py + 16)
            local r, g = output:getPixel(math.floor(fx), math.floor(fy - 8 * f.scale * q))
            T.check(r > 0.7 and g < 0.4, "GPU: upright actor anchors to projected feet")
          end
          output:release()
        end
      end
    end
    ctx.settings.mode = "full"
    Player.px, Player.py = 200, 300
    Tilt.angle, Tilt.level = math.rad(35), 2
    local normal = ctx.capture("screen", 1, 720, 480)
    local mirrors = Renderer.mirrorsWorldOverride
    Renderer.mirrorsWorldOverride = function() return true end
    local mirrored = ctx.capture("screen", 1, 720, 480)
    Renderer.mirrorsWorldOverride = mirrors
    local differences = 0
    for y = 0, 479, 3 do
      for x = 0, 719, 3 do
        local r, g, b = normal:getPixel(x, y)
        local r2, g2, b2 = mirrored:getPixel(x, y)
        if math.abs(r - r2) + math.abs(g - g2) + math.abs(b - b2) > 0.01 then
          differences = differences + 1
        end
      end
    end
    T.eq(differences, 0, "GPU: audited nativeFlip compensation preserves complete Tilt image and UI")
    normal:release()
    mirrored:release()

    local render = assert(loadfile(ctx.root .. "\\tilt_render.lua"))()
    local Field = require("src.core.game3.field_view")
    local billboard = Field._billboard
    local f = Geometry.project(bounds, 720, 480, 200, 300, "full", 1, nil, Tilt)
    lg.push("all")
    T.raises(function()
      render.actors(Tilt, Field, f, 0, 0, function()
        Field._billboard = {}
        error("injected upright failure")
      end)
    end, "injected upright failure", "upright failure propagates")
    lg.pop()
    T.eq(Field._billboard, billboard, "upright failure restores field billboard state")
    T.eq(Tilt.groundPoint, savedPoint, "upright failure restores engine projection helper")
    T.eq(lg.translate, savedTranslate, "upright failure restores graphics translation")
    local depth = lg.getStackDepth()
    lg.push("all")
    lg.origin()
    render.actors(Tilt, Field, f, 0, 0, function()
      for _, foot in ipairs({ { 200, 100 }, { 200, 400 } }) do
        local sx, sy, q = Tilt.groundPoint(foot[1], foot[2])
        lg.push()
        lg.translate(sx - foot[1], sy - foot[2])
        local x, y = lg.transformPoint(foot[1], foot[2])
        local wantX, wantY = f.point(foot[1], foot[2])
        T.check(math.abs(x - wantX) + math.abs(y - wantY) < 0.001,
          "billboard scaling leaves projected feet invariant")
        local _, top = lg.transformPoint(foot[1], foot[2] - 32)
        T.check(math.abs(y - top - 32 * f.scale * q) < 0.001,
          "billboard matrix scales sprite-local height by depth")
        local right = lg.transformPoint(foot[1] + 16, foot[2])
        T.check(math.abs(right - x - 16 * f.scale * q) < 0.001,
          "billboard matrix scales width by the same perspective factor")
        lg.translate(3, -5)
        local localX, localY = lg.transformPoint(foot[1], foot[2])
        T.check(math.abs(localX - x - 3 * f.scale * q)
          + math.abs(localY - y + 5 * f.scale * q) < 0.001,
          "sprite-local animation transforms are preserved after the foot handoff")
        lg.pop()
      end
    end)
    lg.pop()
    T.eq(lg.getStackDepth(), depth, "per-actor scaling does not leak matrix pushes")
    lg.push("all")
    T.raises(function()
      render.actors(Tilt, Field, f, 0, 0, function()
        Tilt.groundPoint(200, 100)
        lg.translate(0, 0)
      end)
    end, "transform order", "unknown billboard handoff is rejected rather than distorting sprites")
    lg.pop()
    T.eq(lg.translate, savedTranslate, "handoff rejection restores global translation")
    T.eq(Tilt.groundPoint, savedPoint, "handoff rejection restores projection")
    local draw, mesh = lg.draw, Renderer:tiltMesh()
    local priorTexture = mesh:getTexture()
    local raster = lg.newCanvas(643, 483)
    lg.draw = function(object, ...)
      if object == mesh then error("injected mesh draw failure") end
      return draw(object, ...)
    end
    T.raises(function() render.ground(Renderer, raster, f, -1, -1, 643, 483) end,
      "injected mesh draw failure", "ground mesh error propagates")
    lg.draw = draw
    T.eq(mesh:getTexture(), priorTexture, "ground error restores engine mesh texture without retaining camera raster")
    raster:release()

    ctx.settings.mode = "normal"
    ctx.capture("screen", 1, 720, 480):release()
    ctx.settings.mode = "full"
    local allocate, publish = lg.newCanvas, Renderer.setWorldOverride
    local allocations, publications = 0, 0
    lg.newCanvas = function(w, h, ...)
      if w == 720 and h == 480 then
        allocations = allocations + 1
        -- Target capture + three camera outputs precede the upright allocation.
        if allocations == 5 then error("injected SCREEN upright allocation failure") end
      end
      return allocate(w, h, ...)
    end
    Renderer.setWorldOverride = function(self, canvas)
      if canvas then publications = publications + 1 end
      return publish(self, canvas)
    end
    local fallback = ctx.capture("screen", 1, 720, 480)
    lg.newCanvas, Renderer.setWorldOverride = allocate, publish
    T.eq(allocations, 5, "upright allocation failure fixture reached additional SCREEN buffer")
    T.eq(publications, 0, "failed SCREEN allocation falls back to Retro without incomplete publication")
    local visible = 0
    for y = 130, 479, 5 do
      for x = 0, 719, 5 do
        local r, g = fallback:getPixel(x, y)
        if g > 0.7 and r < 0.2 then visible = visible + 1 end
      end
    end
    T.check(visible > 20, "allocation fallback still draws tilted camera rather than disabling it")
    T.eq(Tilt.angle, math.rad(35), "allocation fallback preserves live Tilt")
    fallback:release()
    if ctx.scene and ctx.setTime then
      local Session = require("src.core.game3.runtime")
      local oldMap, oldFlash = Session.session.map, Field._flashMapId
      local oldTransition, oldDuration = ctx.settings.transition, ctx.settings.duration
      local redPixels = love.image.newImageData(1024, 1024)
      redPixels:mapPixel(function() return 1, 0, 0, 1 end)
      local redImage = lg.newImage(redPixels)
      for _, resolution in ipairs({ "retro", "screen" }) do
        for _, mode in ipairs({ "full", "partial" }) do
          for _, effect in ipairs({ "fade", "horizontal", "vertical" }) do
            ctx.settings.mode = "normal"
            ctx.capture(resolution, 1, 720, 480):release()
            ctx.settings.mode, ctx.settings.transition, ctx.settings.duration = mode, effect, 1000
            Tilt.angle, Tilt.level = math.rad(35), 2
            ctx.native.image = image
            Session.session.map, Field._flashMapId = "FIXTURE", "FIXTURE"
            ctx.setTime(100)
            ctx.capture(resolution, 1, 720, 480):release()
            ctx.native.image = redImage
            Session.session.map, Field._flashMapId = "SECOND", "SECOND"
            ctx.setTime(101)
            ctx.capture(resolution, 1, 720, 480):release()
            ctx.setTime(101.5)
            local midpoint = ctx.capture(resolution, 1, 720, 480)
            local r, g, b = midpoint:getPixel(360, 300)
            if effect == "fade" then
              T.check(r < 0.01 and g < 0.01 and b < 0.01,
                "GPU: composed Tilt world reaches black fade midpoint")
            elseif mode == "partial" then
              local x1, y1 = effect == "horizontal" and 100 or 360, effect == "vertical" and 100 or 300
              local x2, y2 = effect == "horizontal" and 620 or 360, effect == "vertical" and 400 or 300
              local r1, g1 = midpoint:getPixel(x1, y1)
              local r2, g2 = midpoint:getPixel(x2, y2)
              T.check(g1 > 0.7 and r1 < 0.2 and r2 > 0.7 and g2 < 0.2,
                "GPU: Tilt scroll preserves separately composed outgoing/incoming worlds")
            end
            local ur, ug = midpoint:getPixel(35, 35)
            T.check(ur > 0.9 and ug < 0.1, "GPU: Tilt camera transition leaves UI stationary")
            midpoint:release()
            Tilt.angle = math.rad(50)
            local changed = ctx.capture(resolution, 1, 720, 480)
            r, g = changed:getPixel(360, 300)
            T.check(r > 0.7 and g < 0.2, "GPU: live Tilt angle change discards stale transition sources")
            changed:release()
          end
        end
      end
      Session.session.map, Field._flashMapId = oldMap, oldFlash
      ctx.settings.transition, ctx.settings.duration = oldTransition, oldDuration
      ctx.native.image = image
      ctx.capture("screen", 1, 720, 480):release()
      redPixels:release()
      redImage:release()
    end
  end
  if require("src.core.Version").engine == "0.3.22" then
    local Effects = require("src.core.game3.field_effects")
    local collect, transition = Effects.collectActors, ctx.settings.transition
    ctx.settings.transition = "none"
    Player.px, Player.py = 320, 240
    local effect = { x = 368, y = 240, kind = "effect", elevation = 3,
      draw = function(self, camX, camY)
        lg.setColor(0, 0, 1, 1)
        lg.rectangle("fill", self.x - camX + 4, self.y - camY + 4, 8, 12)
      end }
    Effects.collectActors = function(actors) actors[#actors + 1] = effect end
    for _, degrees in ipairs({ 15, 35, 50 }) do
      Tilt.angle, Tilt.level = math.rad(degrees), 1
      for _, mode in ipairs({ "full", "partial" }) do
        ctx.settings.mode = mode
        local output = ctx.capture("screen", 1, 720, 480)
        local f = Geometry.project(bounds, 720, 480, Player.px, Player.py, mode, 1,
          mode == "partial" and require("src.render.Zoom").scale(3) or nil, Tilt)
        local x, y, q = f.point(effect.x + 8, effect.y + 16)
        local r, g, b = output:getPixel(math.floor(x), math.floor(y - 6 * f.scale * q))
        T.check(b > 0.8 and r < 0.1 and g < 0.1,
          "GPU: 0.3.22 collected effect callback remains upright at projected feet")
        output:release()
      end
    end
    Effects.collectActors, ctx.settings.transition = collect, transition
  end
  ctx.native.image, ctx.native.testQuad = oldImage, oldQuad
  ctx.settings.mode, ctx.settings.zoom, ctx.settings.zoom_style = oldMode, oldZoom, oldStyle
  Player.px, Player.py = oldX, oldY
  Tilt.angle, Tilt.level = originalAngle, originalLevel
  ctx.capture("screen", 1, 720, 480):release()
  pixels:release()
  image:release()
  quad:release()
end
