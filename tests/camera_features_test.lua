return function(ctx)
  local T, settings, scene = ctx.T, ctx.settings, ctx.scene
  local lg = love.graphics
  local Map = require("src.core.game3.map")
  local Session = require("src.core.game3.runtime")
  local Player = require("src.core.game3.player")
  local Field = require("src.core.game3.field_view")
  local Native = require("src.core.game3.tileset_native")
  local Tilt = require("src.render.Tilt")
  local Geometry = assert(loadfile(ctx.root .. "\\tilt_geometry.lua"))()
  local Battle = ctx.nativeBattle
  local battleProxy = require("src.core.game3.battle_transition")
  local originalSettings = {}
  for k, v in pairs(settings) do originalSettings[k] = v end
  local maps, oldMap, oldFlash = scene.data.maps, Session.session.map, Field._flashMapId
  local oldImage, oldGet, oldSample = ctx.native.image, Native.get, Map.worldMidAt
  local oldAngle, oldLevel, oldX, oldY = Tilt.angle, Tilt.level, Player.px, Player.py
  local oldActive = battleProxy.isActive
  local greenData, redData = love.image.newImageData(16, 16), love.image.newImageData(16, 16)
  greenData:mapPixel(function() return 0, 1, 0, 1 end)
  redData:mapPixel(function() return 1, 0, 0, 1 end)
  local greenImage, redImage = lg.newImage(greenData), lg.newImage(redData)
  local function layout(w, h, pair)
    return { width = w, height = h, pair = pair, midAt = function() return 0 end }
  end
  local function countGreen(image)
    local count = 0
    for y = 100, 475, 5 do
      for x = 0, 715, 5 do
        local r, g = image:getPixel(x, y)
        if g > 0.8 and r < 0.1 then count = count + 1 end
      end
    end
    return count
  end
  local ok, err = xpcall(function()
    settings.transition, settings.framing, settings.void_fill = "none", "scene", "black"
    settings.zoom, settings.zoom_style, settings.connected = 200, "consistent", false
    ctx.native.image = greenImage
    Session.session.map, Field._flashMapId = "FIXTURE", "FIXTURE"
    local room = { width = 4, height = 4, midLayout = layout(4, 4, "fixture"), pair = "fixture" }
    scene.data.maps = { FIXTURE = room }
    Player.px, Player.py = 16, 16
    for _, angle in ipairs({ 0, 35 }) do
      Tilt.angle, Tilt.level = math.rad(angle), angle == 0 and 0 or 2
      for _, resolution in ipairs({ "retro", "screen" }) do
        settings.mode, settings.max_zoom = "partial", 0
        local uncapped = ctx.capture(resolution, 1, 720, 480)
        settings.max_zoom = 100
        local capped = ctx.capture(resolution, 1, 720, 480)
        T.check(countGreen(capped) > 10 and countGreen(capped) < countGreen(uncapped) / 2,
          "GPU: actual bounded ceiling keeps a small interior comfortably sized")
        local r, g, b = capped:getPixel(0, 300)
        T.check(r + g + b < 0.01, "GPU: capped small room exposes BLACK backdrop, not native border tiles")
        local Fill = require("src.core.game3.void_fill")
        local oldFill = Fill.mode
        Fill.setMode("map")
        for _, fill in ipairs({ "game", "extrude" }) do
          settings.void_fill, settings.extrude_depth = fill, 2
          local filled = ctx.capture(resolution, 1, 720, 480)
          r, g = filled:getPixel(0, 300)
          T.check(g > 0.8 and r < 0.1, "GPU: capped room honors " .. fill .. " backdrop with and without Tilt")
          filled:release()
        end
        Fill.mode, settings.void_fill = oldFill, "black"
        capped:release(); uncapped:release()
      end
    end
    settings.mode, settings.max_zoom = "full", 0
    Player.px, Player.py = 80, 80
    local main = { width = 40, height = 30, midLayout = layout(40, 30, "fixture"), pair = "fixture",
      connections = { { dir = "west", map = "NEIGHBOR", offset = 5 } } }
    local neighbor = { width = 4, height = 10, midLayout = layout(4, 10, "neighbor"), pair = "neighbor" }
    scene.data.maps = { FIXTURE = main, NEIGHBOR = neighbor }
    Native.get = function(pair)
      if pair == "neighbor" then return { image = redImage } end
      return oldGet(pair)
    end
    Map.worldMidAt = ctx.worldSample
    local world, root, reachW, reachH, list = Map.world, Map._worldRoot,
      Map._worldReachW, Map._worldReachH, Map.neighborList
    for _, angle in ipairs({ 0, 35 }) do
      Tilt.angle, Tilt.level = math.rad(angle), angle == 0 and 0 or 2
      for _, resolution in ipairs({ "retro", "screen" }) do
        settings.connected = false
        local before = ctx.capture(resolution, 1, 720, 480)
        settings.connected = true
        local after = ctx.capture(resolution, 1, 720, 480)
        local colored = 0
        for y = 120, 470, 4 do
          for x = 0, 240, 4 do
            local r, g = after:getPixel(x, y)
            local br, bg = before:getPixel(x, y)
            if r > 0.8 and g < 0.1 and br + bg < 0.1 then colored = colored + 1 end
          end
        end
        T.check(colored > 4, "GPU: connected context shows offset neighbor's own tileset outside primary framing")
        local r, g, b = after:getPixel(0, 470)
        T.check(r + g + b < 0.01, "GPU: gaps between offset maps retain backdrop")
        local r1, g1 = before:getPixel(360, 300)
        local r2, g2 = after:getPixel(360, 300)
        T.check(math.abs(r1 - r2) + math.abs(g1 - g2) < 0.01,
          "GPU: connected scenery does not change primary framing")
        T.eq(Map.world, world, "neighbor render restores native world")
        T.eq(Map.neighborList, list, "neighbor render restores native neighbor list")
        T.eq(Map._worldRoot, root, "neighbor render does not corrupt cached root")
        T.eq(Map._worldReachW, reachW, "neighbor render does not alter cached horizontal reach")
        T.eq(Map._worldReachH, reachH, "neighbor render does not alter cached vertical reach")
        settings.neighbor_shade, settings.neighbor_darkness, settings.neighbor_distance = "uniform", 60, 2
        local uniform = ctx.capture(resolution, 1, 720, 480)
        settings.neighbor_shade = "gradient"
        local gradient = ctx.capture(resolution, 1, 720, 480)
        local low, high, checked, primary = 1, 0, 0, 0
        local projection = angle > 0 and Geometry.project({ x = 0, y = 0, w = 640, h = 480 },
          resolution == "retro" and 240 or 720, resolution == "retro" and 160 or 480,
          Player.px, Player.py, "full", 2, nil, Tilt) or nil
        for y = 120, 470, 4 do
          for x = 0, 715, 4 do
            local ar, ag = after:getPixel(x, y)
            local br, bg = before:getPixel(x, y)
            local ur, ug = uniform:getPixel(x, y)
            local gr, gg = gradient:getPixel(x, y)
            local wx = x - 40
            if projection then
              wx = projection.worldAt((x + 0.5) / (resolution == "retro" and 3 or 1),
                (y + 0.5) / (resolution == "retro" and 3 or 1))
            end
            if ar > 0.99 and ag < 0.01 and br + bg < 0.01 and wx < -3 then
              T.check(math.abs(ur - 0.4) < 0.02 and ug < 0.01,
                "GPU: uniform shading darkens only connected terrain")
              T.check(gr >= 0.38 and gr <= 1.01 and gg < 0.01,
                "GPU: gradient stays within configured darkness range")
              low, high, checked = math.min(low, gr), math.max(high, gr), checked + 1
            elseif br < 0.01 and bg > 0.99 and ag > 0.99 then
              T.check(ur < 0.01 and ug > 0.99 and gr < 0.01 and gg > 0.99,
                ("GPU: current area unchanged angle=%s resolution=%s pixel=%s,%s before=%s,%s uniform=%s,%s gradient=%s,%s")
                  :format(angle, resolution, x, y, ar, ag, ur, ug, gr, gg))
              primary = primary + 1
            end
          end
        end
        T.check(checked > 4 and primary > 20, "GPU: shading checks actual neighbor and primary tiles")
        T.check(high - low > 0.08, "GPU: gradient becomes darker with distance from primary boundary")
        uniform:release(); gradient:release()
        settings.neighbor_shade = "off"
        local published = require("src.render.Renderer").setWorldOverride
        local publications = 0
        local Renderer = require("src.render.Renderer")
        Renderer.setWorldOverride = function(self, image)
          if image then publications = publications + 1 end
          return published(self, image)
        end
        local allocate = lg.newCanvas
        lg.newCanvas = function(w, h, ...)
          if w > 643 and w ~= 720 then error("injected neighbor raster allocation failure") end
          return allocate(w, h, ...)
        end
        -- Force reallocation of the expanded optional raster.
        settings.connected = false
        ctx.capture(resolution, 1, 720, 480):release()
        settings.connected = true
        local fallback = ctx.capture(resolution, 1, 720, 480)
        lg.newCanvas, Renderer.setWorldOverride = allocate, published
        local fr, fg = fallback:getPixel(360, 300)
        T.check(math.abs(fr - r1) + math.abs(fg - g1) < 0.01,
          "GPU: optional neighbor allocation failure retains primary camera landmark")
        if resolution == "screen" then
          T.check(publications >= 2, "GPU: neighbor failure does not downgrade Screen resolution")
        end
        T.eq(ctx.seen.w, 643, "GPU: failed neighbors return to primary raster, not vanilla camera")
        fallback:release()
        settings.connected = false
        ctx.capture(resolution, 1, 720, 480):release()
        settings.connected = true
        before:release(); after:release()
      end
    end
    Session.session.map, Field._flashMapId = "NEIGHBOR", "NEIGHBOR"
    Player.px, Player.py = 16, 32
    settings.neighbor_shade, settings.neighbor_darkness = "uniform", 100
    Tilt.angle, Tilt.level = 0, 0
    local entered = ctx.capture("screen", 1, 720, 480)
    local enteredRed, enteredGreen = entered:getPixel(360, 300)
    T.check(enteredRed > 0.99 and enteredGreen < 0.01,
      "GPU: previously shaded neighbor becomes fully bright upon entering it")
    entered:release()
    Session.session.map, Field._flashMapId = "FIXTURE", "FIXTURE"
    Player.px, Player.py = 80, 80
    settings.connected = false
    Native.get, Map.worldMidAt = oldGet, oldSample
    scene.data.maps = maps
    battleProxy.isActive = Battle.isActive
    scene.battleTransition = Battle
    for _, angle in ipairs({ 0, 35 }) do
      Tilt.angle, Tilt.level = math.rad(angle), angle == 0 and 0 or 2
      for _, mode in ipairs({ "full", "partial" }) do
        settings.mode = mode
        for _, resolution in ipairs({ "retro", "screen" }) do
          local before = ctx.capture(resolution, 1, 720, 480)
          local w, h, x, y = ctx.seen.w, ctx.seen.h, ctx.seen.panX, ctx.seen.panY
          for _, effect in ipairs({ Battle.ID.SLICE, Battle.ID.WAVE, Battle.ID.BIG_POKEBALL,
            Battle.ID.GRID_SQUARES, Battle.ID.POKEBALLS_TRAIL, Battle.ID.LORELEI }) do
            local completed = 0
            Battle.start(effect, { skipIntro = true }, function() completed = completed + 1 end)
            local first = ctx.capture(resolution, 1, 720, 480)
            T.eq(ctx.seen.w, w, "battle entry retains captured camera width")
            T.eq(ctx.seen.h, h, "battle entry retains captured camera height")
            T.eq(ctx.seen.panX, x, "battle entry retains horizontal framing")
            T.eq(ctx.seen.panY, y, "battle entry retains vertical framing")
            T.eq(scene.hadOverride, false, "native battle effect cannot be bypassed by screen override")
            T.eq(Battle._frame, 0, "camera drawing does not advance battle timing")
            T.eq(completed, 0, "camera drawing does not trigger battle callback")
            local difference = math.abs(countGreen(first) - countGreen(before))
            T.check(difference < 100, "GPU: first battle frame keeps the same visible camera footprint")
            first:release()
            for _ = 1, 35 do Battle.tick() end
            local frame = Battle._frame
            local animated = ctx.capture(resolution, 1, 720, 480)
            local r, g = animated:getPixel(35, 35)
            T.check(r > 0.99 and g < 0.01, "GPU: native battle effects do not repaint menu/UI plane")
            T.eq(Battle._frame, frame, "native effect renders once without advancing simulation")
            animated:release()
            local ticks = 35
            while Battle.isActive() and ticks < 2000 do Battle.tick(); ticks = ticks + 1 end
            T.eq(completed, 1, "native battle effect finishes and invokes its callback once")
          end
          before:release()
        end
      end
    end
    Battle.abort()
    scene.battleTransition = nil
    settings.mode, settings.transition, settings.duration = "partial", "slide", 1000
    Tilt.angle, Tilt.level = 0, 0
    for _, direction in ipairs({ "east", "west", "north", "south" }) do
      settings.mode = "normal"
      ctx.capture("screen", 1, 720, 480):release()
      settings.mode = "partial"
      Session.session.map, Field._flashMapId = "FIXTURE", "FIXTURE"
      ctx.native.image = greenImage
      ctx.setTime(10)
      ctx.capture("screen", 1, 720, 480):release()
      ctx.crossing(scene, "SECOND", direction)
      Session.session.map, Field._flashMapId = "SECOND", "SECOND"
      ctx.native.image = redImage
      ctx.setTime(11)
      ctx.capture("screen", 1, 720, 480):release()
      ctx.setTime(11.5)
      local halfway = ctx.capture("screen", 1, 720, 480)
      local px = direction == "east" and 600 or direction == "west" and 100 or 360
      local py = direction == "south" and 400 or direction == "north" and 100 or 300
      local r, g = halfway:getPixel(px, py)
      T.check(r > 0.8 and g < 0.1, "GPU: destination slides in from crossing direction " .. direction)
      halfway:release()
    end
    local Runtime = require("src.mods.Runtime")
    local savedHooks = Runtime.hooks
    Runtime.hooks = require("src.mods.Hooks").new()
    local previewGame = { phase = "field", data = scene.data, draw = function() end, reset = function() end }
    local mod = {
      options = { get = function(_, key) return settings[key] end },
      log = { warn = function() end, info = function() end, error = function() end },
      events = { on = function() end },
      hooks = { wrap = function(_, name, callback)
        Runtime.hooks:wrap(name, callback, 0, "preview_render_test")
      end },
      read = function(_, path)
        local file = assert(io.open(ctx.root .. "\\" .. path, "rb"))
        local text = file:read("*a")
        file:close()
        return text
      end,
    }
    local Adapter = assert(loadfile(ctx.root .. "\\adapter_gen3.lua"))()
    local G = assert(loadfile(ctx.root .. "\\geometry.lua"))()
    local C = assert(loadfile(ctx.root .. "\\compatibility.lua"))()
    local preview = Adapter.start(mod, G, nil, nil, C.new(mod))
    Runtime.hooks:call("core.update", function() end, previewGame, 0)
    local target = lg.newCanvas(240, 160)
    local beforeX, beforeY, originalTilt = Player.px, Player.py, Tilt.active
    local depth = lg.getStackDepth()
    for _, resolution in ipairs({ "retro", "screen" }) do
      settings.resolution, settings.mode, settings.zoom = resolution, "partial", 100
      Tilt.angle, Tilt.level = math.rad(35), 2
      lg.setCanvas(target)
      lg.origin()
      T.eq(preview.draw(previewGame), true, "real adapter renders paused preview into UI target")
      local width = ctx.seen.w
      settings.zoom = 200
      T.eq(preview.draw(previewGame), true, "real preview refreshes after changing zoom")
      T.check(ctx.seen.w < width, "real preview reflects new zoom rather than a cached screenshot")
      T.eq(lg.getCanvas(), target, "real preview restores the UI canvas")
      T.eq(lg.getStackDepth(), depth, "real preview balances graphics state")
      T.eq(Tilt.active, originalTilt, "real preview restores engine Tilt callback")
      T.eq(Player.px, beforeX, "real preview never moves the player horizontally")
      T.eq(Player.py, beforeY, "real preview never moves the player vertically")
    end
    previewGame:reset()
    Runtime.hooks = savedHooks
    lg.setCanvas()
    target:release()
  end, debug.traceback)
  Battle.abort()
  scene.battleTransition = nil
  battleProxy.isActive = oldActive
  for k in pairs(settings) do settings[k] = nil end
  for k, v in pairs(originalSettings) do settings[k] = v end
  scene.data.maps = maps
  Session.session.map, Field._flashMapId = oldMap, oldFlash
  ctx.native.image, Native.get, Map.worldMidAt = oldImage, oldGet, oldSample
  Tilt.angle, Tilt.level, Player.px, Player.py = oldAngle, oldLevel, oldX, oldY
  greenData:release(); redData:release()
  -- Cached engine batches can still own these images until the next draw.
  if not ok then error(err, 0) end
end
