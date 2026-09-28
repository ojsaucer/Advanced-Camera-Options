local Adapter = {}
function Adapter.withinCanvasBudget(w, h, rasterW, rasterH, upright, backdropPixels)
  return w * h * (upright and 4 or 3) + rasterW * rasterH + (backdropPixels or 0) <= 32 * 1024 * 1024
end
local function pack(...) return { n = select("#", ...), ... } end
local function result(r)
  if not r[1] then error(r[2], 0) end
  return unpack(r, 2, r.n)
end

function Adapter.start(mod, G, tiltModules, Backdrop, compatibility)
  if not compatibility.check("camera") then return end
  local capabilities = {}
  for _, feature in ipairs({ "screen", "tilt", "terrain", "backdrop", "shade", "connections" }) do
    capabilities[feature] = compatibility.check(feature)
  end
  local Runtime = require("src.mods.Runtime")
  local GameVersion = require("src.core.GameVersion")
  local Field = require("src.core.game3.field_view")
  local Player = require("src.core.game3.player")
  local Session = require("src.core.game3.runtime")
  local Map = require("src.core.game3.map")
  local Connections = compatibility.modules["src.core.game3.connections"]
  local BattleTransition = require("src.core.game3.battle_transition")
  local Collision = compatibility.modules["src.core.game3.collision"]
  local Tilt = require("src.render.Tilt")
  local Renderer = require("src.render.Renderer")
  local Zoom = compatibility.modules["src.render.Zoom"]
  local Warp = require("src.core.game3.warp")
  local Fade = require("src.ui.game3.fade")
  local lg = love.graphics
  local shade
  if capabilities.shade then
    local FieldWeather = compatibility.modules["src.core.game3.field_weather"]
    local Weather = compatibility.modules["src.core.game3.weather"]
    shade = function(w, h)
      -- Only uniform shade can be replayed on a repeat tile. Spatial weather
      -- and effects must retain their original coordinates and side effects.
      if FieldWeather.getWeather() == Weather.SHADE then FieldWeather.draw(0, 0, w, h) end
    end
  end
  local function tiltModule(name)
    local text, err = mod:read(name .. ".lua")
    assert(text, err)
    return assert(loadstring(text, "@static_camera/" .. name .. ".lua"))()
  end
  Backdrop = Backdrop or tiltModule("void_backdrop")
  local function tiltSupport()
    if not tiltModules then
      tiltModules = { geometry = tiltModule("tilt_geometry"), render = tiltModule("tilt_render") }
    end
    return tiltModules.render.available(Renderer)
  end
  local attachment, update
  local warnings = {}
  local function warn(key, message)
    if warnings[key] then return end
    warnings[key] = true
    mod.log:warn("%s", message)
  end
  local function number(key, default, lo, hi)
    local n = mod.options:get(key)
    if G.finite(n) and n >= lo and n <= hi then return n end
    warn(key, "Invalid " .. key .. " setting; using its default.")
    return default
  end
  local function choice(key, default, choices)
    local value = mod.options:get(key)
    if choices[value] then return value end
    warn(key, "Invalid " .. key .. " setting; using its default.")
    return default
  end
  local function zoomLevel()
    local value = mod.options:get("zoom")
    if not G.finite(value) then
      warn("zoom", "Invalid zoom setting; using 200%.")
      return 2
    end
    local bounded = G.clamp(math.floor(value / 5 + 0.5) * 5, 5, 200)
    if value ~= bounded then
      warn("zoom", "Zoom is limited to 5-200% in 5% steps; open mod options to update the saved value.")
    end
    return bounded / 100
  end
  local function alive()
    for _, link in ipairs((Runtime.hooks.chains or {})["core.update"] or {}) do
      if link.callback == update then return true end
    end
    return false
  end
  local function release(object)
    if object then object:release() end
  end
  local cacheKeys = { "_nativeBatches", "_nativeOverBatches", "_nativeOverByRow",
    "_nativeBx", "_nativeBy", "_nativePair", "_nativeOverPair", "_nativeVoid",
    "_nativeDirty", "_nativeOverOx", "_nativeOverOy", "_nativeCellsByPair", "_nativeCellPool" }

  local function bind(game)
    local oldDraw, oldReset = game.draw, game.reset
    local rawDraw, rawReset = rawget(game, "draw"), rawget(game, "reset")
    local draw, reset, detached, fault
    local live, last, outgoing, bw, bh, valid, area, motion
    local raster, rw, rh, upright
    local tiltRequested, projectionKey
    local envelopeKey, envelope
    local cache, cacheKey, cropKey, crop = {}, nil, nil, nil
    local published, failedScreenKey
    local presentation = {}
    presentation.shading = tiltModule("boundary_shading").new(warn)
    local backdrop = capabilities.backdrop and Backdrop.new(warn, shade)
    local backdropPixels = 0

    local function clearCache()
      for _, key in ipairs({ "_nativeBatches", "_nativeOverBatches" }) do
        for _, batch in pairs(cache[key] or {}) do release(batch) end
      end
      cache, cacheKey = {}, nil
    end
    local function clearCanvases()
      if Renderer.worldOverride and (Renderer.worldOverride == live
        or Renderer.worldOverride == last or Renderer.worldOverride == outgoing
        or Renderer.worldOverride == upright) then
        Renderer:setWorldOverride(nil)
      end
      published = nil
      release(live)
      release(last)
      release(outgoing)
      release(upright)
      upright = nil
      live, last, outgoing = nil, nil, nil
      valid, area, motion = nil, nil, nil
      projectionKey = nil
      presentation.crossing = nil
    end
    local function clear()
      clearCanvases()
      if backdrop then backdrop.dispose() end
      backdropPixels = 0
      release(raster)
      raster, rw, rh = nil, nil, nil
      cropKey, crop, failedScreenKey = nil, nil, nil
      envelopeKey, envelope = nil, nil
      clearCache()
      presentation.shading.dispose()
      presentation.neighborFailure = nil
    end
    local function detach()
      if detached then return end
      detached = true
      if game.draw == draw then game.draw = rawDraw end
      if game.reset == reset then game.reset = rawReset end
      clear()
      if attachment and attachment.game == game then attachment = nil end
    end
    local function active(name, method)
      local m = require(name)
      return type(m[method]) == "function" and m[method]() or false
    end
    local function protected(opts)
      if fault or game.phase ~= "field" or not Session.isActive() then return true end
      if opts and next(opts) ~= nil then return true end
      if Field.hideActors or (Field.cameraPanX or 0) ~= 0 or (Field.cameraPanY or 0) ~= 0
        or active("src.ui.game3.shop_menu", "isShopCamera")
        or active("src.ui.game3.seagallop", "isActive")
        or active("src.core.game3.camera_object", "isActive")
        or (BattleTransition.isActive() and BattleTransition._opts and BattleTransition._opts.overUi)
        or active("src.core.game3.bg", "hasVisible") then return true end
      local oam = require("src.core.game3.oam")
      for _, sprite in pairs(oam._sprites or {}) do
        if sprite.inUse and not sprite.invisible and sprite.layer == "world" then return true end
      end
      return false
    end

    local function boundsFor(id, def, framing, padding)
      local layout = def.midLayout
      local key = tostring(id) .. ":" .. tostring(layout) .. ":" .. framing .. ":" .. padding
      if cropKey == key then return crop end
      crop = { x = 0, y = 0, w = layout.width * 16, h = layout.height * 16 }
      if framing == "reachable" and capabilities.terrain then
        if Collision._mapId ~= id or not Collision._grid then
          warn("collision", "Reachable crop unavailable until collision is ready; using full scene.")
          return crop
        end
        local function terrainStep(x, y, direction)
          local tx, ty = x + direction[1], y + direction[2]
          local lx, ly = Collision.ledgeLanding(game, x, y, direction[3])
          if lx then tx, ty = lx, ly end
          if not Collision.inBounds(tx, ty) then return end
          if not Collision.isWalkable(tx, ty) and not Collision.isWater(tx, ty) then return end
          if not lx and Collision.directionallyImpassable(x, y, tx, ty, direction[3]) then return end
          local elevation = Collision.elevationAt(x, y)
          if Collision.elevationMismatchOn(def, elevation, tx, ty)
            and not Collision.isWater(x, y) and not Collision.isWater(tx, ty) then return end
          return tx, ty
        end
        crop = G.reachable(layout.width, layout.height, Player.px / 16, Player.py / 16,
          padding, terrainStep)
      end
      cropKey = key
      return crop
    end

    local function ensure(w, h)
      if live and bw == w and bh == h then return end
      clearCanvases()
      assert(Adapter.withinCanvasBudget(w, h, 0, 0, false),
        "Camera output exceeds 128 MiB canvas budget")
      bw, bh = w, h
      live, last, outgoing = lg.newCanvas(w, h, { dpiscale = 1 }), nil, nil
      last = lg.newCanvas(w, h, { dpiscale = 1 })
      outgoing = lg.newCanvas(w, h, { dpiscale = 1 })
      for _, canvas in ipairs({ live, last, outgoing }) do canvas:setFilter("nearest", "nearest") end
    end
    local function ensureRaster(w, h, extra)
      local limits = lg.getSystemLimits and lg.getSystemLimits()
      local maxSize = limits and limits.texturesize or 8192
      assert(w <= maxSize and h <= maxSize, "World raster exceeds GPU texture dimensions")
      assert(Adapter.withinCanvasBudget(bw or 0, bh or 0, w, h, extra, backdropPixels),
        "World raster exceeds 128 MiB camera canvas budget")
      if raster and rw == w and rh == h then return end
      release(raster)
      raster = nil
      raster = lg.newCanvas(w, h, { dpiscale = 1 })
      raster:setFilter("nearest", "nearest")
      rw, rh = w, h
    end
    local function targetSize(w, h)
      if choice("resolution", "retro", { retro = true, screen = true }) ~= "screen" then
        return w, h, false
      end
      if not capabilities.screen then return w, h, false end
      -- A larger intermediate alone would be downsampled by worldCanvas.
      -- Only publish a native image when the real world compositor owns this pass.
      if not presentation.previewing and (not Renderer.worldActive or lg.getCanvas() ~= Renderer.worldCanvas
        or (Renderer.worldOverride and Renderer.worldOverride ~= published)) then
        warn("screen-path", "Screen-resolution output unavailable in this presentation; using Retro.")
        return w, h, false
      end
      local rect = Renderer:frameRects()
      local pw, ph = rect.pw, rect.ph
      local limits = lg.getSystemLimits and lg.getSystemLimits()
      local maxSize = math.min(8192, limits and limits.texturesize or 8192)
      if not G.finite(pw) or not G.finite(ph) or pw < 1 or ph < 1
        or pw > maxSize or ph > maxSize then
        warn("screen-size", "Screen dimensions exceed the camera/GPU limit; using Retro.")
        return w, h, false
      end
      pw, ph = math.floor(pw + 0.5), math.floor(ph + 0.5)
      if failedScreenKey == pw .. ":" .. ph then return w, h, false end
      return pw, ph, true
    end
    local function fenced(fn)
      local depth, canvas = lg.getStackDepth(), pack(lg.getCanvas())
      lg.push("all")
      local r = pack(pcall(fn))
      while lg.getStackDepth() > depth do lg.pop() end
      lg.setCanvas(unpack(canvas, 1, canvas.n))
      return result(r)
    end
    local function paint(canvas, position)
      local a = position[3]
      if a <= 0 then return end
      lg.setColor(a, a, a, a)
      lg.draw(canvas, position[1], position[2])
    end

    local function field(nextDraw, g, w, h, opts)
      if g ~= game or protected(opts) then
        valid, area, motion = nil, nil, nil
        presentation.crossing = nil
        return nextDraw(g, w, h, opts)
      end
      local mode = choice("mode", "normal", { full = true, partial = true, normal = true })
      if mode == "normal" then return nextDraw(g, w, h, opts) end
      w, h = w or 240, h or 160
      if not presentation.previewing then presentation.viewW, presentation.viewH = w, h end
      local session = Session.getSession()
      local id = session and session.map
      local def = id and game.data and game.data.maps and game.data.maps[id]
      local layout = def and def.midLayout
      if not layout or not G.finite(layout.width) or not G.finite(layout.height)
        or layout.width < 1 or layout.height < 1 or layout.width * layout.height > 32768
        or not G.finite(Player.px) or not G.finite(Player.py)
        or not G.finite(w) or not G.finite(h) or w < 1 or h < 1 or w > 8192 or h > 8192 then
        valid, area, motion = nil, nil, nil
        warn("bounds", "Unsupported map/viewport dimensions; preserving the vanilla camera.")
        return nextDraw(g, w, h, opts)
      end

      local renderW, renderH, screen = targetSize(w, h)
      local tilted = tiltRequested and capabilities.tilt
      if tilted and (not G.finite(Tilt.angle) or Tilt.angle < 0
        or Tilt.angle > math.rad(50) + 1e-8 or not G.finite(Tilt.FOCAL) or Tilt.FOCAL <= 0) then
        warn("tilt-projection", "Unsupported Tilt angle/focal distance; using a flat camera.")
        tilted = false
      end
      if tilted then
        local ok, available = pcall(tiltSupport)
        if not ok or not available then
          warn("tilt-unavailable", "Tilt shader/mesh unavailable; using the flat Static Camera: "
            .. tostring(available))
          tilted = false
        end
      end
      local allocated, err = pcall(ensure, renderW, renderH)
      if not allocated and screen then
        failedScreenKey = renderW .. ":" .. renderH
        warn("screen-allocation", "Screen-resolution canvas allocation failed; using Retro: " .. tostring(err))
        clearCanvases()
        renderW, renderH, screen = w, h, false
        allocated, err = pcall(ensure, renderW, renderH)
      end
      if not allocated then
        clear()
        fault = true
        warn("canvas", "Camera disabled after canvas allocation failure: " .. tostring(err))
        return nextDraw(g, w, h, opts)
      end
      local framing = choice("framing", "scene", { scene = true, reachable = true })
      local fill = choice("void_fill", "black", { black = true, game = true, extrude = true })
      local border
      if backdrop then
        if fill == "game" then border = backdrop.resolve(layout, def.pair or layout.pair)
        elseif fill == "extrude" then
          border = backdrop.resolve(layout, def.pair or layout.pair, "extrude",
            math.floor(number("extrude_depth", 1, 1, 16)))
        else backdrop.dispose() end
      end
      backdropPixels = border and (border.pixels or border.w * border.h) or 0
      local bounds = boundsFor(id, def, framing, math.floor(number("padding", 1, 0, 4)))
      -- A crop never hides the player after a same-map teleport or terrain change.
      -- Expand only; ordinary walking cannot shrink/recenter a Full Static scene.
      local right = math.max(bounds.x + bounds.w, math.min(layout.width * 16, Player.px + 16))
      local bottom = math.max(bounds.y + bounds.h, math.min(layout.height * 16, Player.py + 16))
      local left, top = math.min(bounds.x, math.max(0, Player.px)), math.min(bounds.y, math.max(0, Player.py))
      if left ~= bounds.x or top ~= bounds.y or right ~= bounds.x + bounds.w or bottom ~= bounds.y + bounds.h then
        warn("crop-expanded", "Player left the cached terrain crop; expanding it to keep them visible.")
        bounds.x, bounds.y, bounds.w, bounds.h = left, top, right - left, bottom - top
      end
      local normalScale = screen and Zoom.scale(Renderer:fitScale()) or 1
      local limit = number("max_zoom", 0, 0, 200)
      local maxScale = limit > 0 and normalScale * math.max(5, math.floor(limit / 5 + 0.5) * 5) / 100 or nil
      local connected = mode == "full" and mod.options:get("connected") == true and capabilities.connections
      local neighborKey = tostring(id) .. ":" .. tostring(layout) .. ":" .. renderW .. ":" .. renderH
      if not connected then presentation.neighborFailure = nil end
      if presentation.neighborFailure == neighborKey then connected = false end
      local neighborShade = connected and choice("neighbor_shade", "off",
        { off = true, uniform = true, gradient = true }) or "off"
      local referenceScale
      if mode == "partial" and choice("zoom_style", "consistent",
        { consistent = true, relative = true }) == "consistent" then
        -- Retro is enlarged later by the engine. Native output bypasses that
        -- blit, so apply its exact scale here, not a rounded viewport ratio.
        referenceScale = normalScale
      end
      local signature = table.concat({ mode, framing, number("padding", 1, 0, 4),
        tilted and Tilt.angle or "flat", referenceScale or "relative", zoomLevel(), fill,
        maxScale or "uncapped", fill == "extrude" and number("extrude_depth", 1, 1, 16) or 0 }, ":")
      if projectionKey ~= signature then
        valid, area, motion, presentation.crossing = nil, nil, nil, nil
      end
      projectionKey = signature
      local frame
      if tilted then
        local key = tostring(id) .. ":" .. tostring(def)
        if envelopeKey ~= key then envelopeKey, envelope = key, nil end
        local Ow = require("src.core.game3.ow_sprites")
        local Objects = require("src.core.game3.objects")
        local Space = package.loaded["src.core.game3.scripting.space"]
        local sizes = {}
        local function include(gid, fallback)
          local sprite = gid and Ow.get and Ow.get(gid)
          sizes[#sizes + 1] = sprite or fallback
          if gid and not sprite then
            warn("upright-size", "Some upright sprite metadata is unavailable; reserving a 64px actor envelope.")
          end
        end
        include(Ow.playerGraphicsId and Ow.playerGraphicsId(game), { width = 16, height = 32 })
        for _, obj in pairs(def.objects or {}) do
          local gid = Space and Space.resolveObjectGraphicsId and Space.resolveObjectGraphicsId(obj)
            or obj.graphicsId or obj.graphics
          include(gid, { width = 64, height = 64 })
        end
        if Objects.hasMap and Objects.hasMap() and Objects.forDraw then
          for _, obj in ipairs(Objects.forDraw()) do
            include(obj.graphicsId or (obj.def and (obj.def.graphicsId or obj.def.graphics)),
              { width = 64, height = 64 })
          end
        end
        local nextEnvelope = tiltModules.geometry.envelope(sizes, envelope)
        if envelope and (nextEnvelope.left > envelope.left or nextEnvelope.top > envelope.top
          or nextEnvelope.right > envelope.right or nextEnvelope.bottom > envelope.bottom) then
          warn("upright-grown", "A larger upright sprite appeared; expanding the stationary Full framing envelope.")
          valid, area, motion = nil, nil, nil
        end
        envelope = nextEnvelope
        frame = tiltModules.geometry.project(bounds, renderW, renderH, Player.px, Player.py,
          mode, zoomLevel(), referenceScale, Tilt, envelope, maxScale)
      else
        frame = G.project(bounds, renderW, renderH, Player.px, Player.py, mode,
          zoomLevel(), referenceScale, maxScale)
      end
      local scopedWorld = { { id = id, def = def, ox = 0, oy = 0 } }
      local terrain = { bounds }
      if connected then
        for _, conn in ipairs(Connections.each(def)) do
          local neighbor = game.data.maps[conn.map]
          if neighbor and conn.map ~= id then
            Map.ensureMidLayout(game, conn.map, neighbor)
            local nw, nh = Connections.sizeOf(neighbor)
            if neighbor.midLayout and G.finite(nw) and G.finite(nh) and nw > 0 and nh > 0
              and nw * nh <= 32768 and G.finite(conn.offset) then
              local ox = conn.dir == "east" and layout.width or conn.dir == "west" and -nw or conn.offset
              local oy = conn.dir == "south" and layout.height or conn.dir == "north" and -nh or conn.offset
              scopedWorld[#scopedWorld + 1] = { id = conn.map, def = neighbor, ox = ox, oy = oy }
              terrain[#terrain + 1] = { x = ox * 16, y = oy * 16, w = nw * 16, h = nh * 16 }
            else
              warn("neighbor-" .. conn.map, "Connected map has unsupported terrain: " .. conn.map)
            end
          end
        end
      end
      local visible = { x = frame.x - frame.dx / frame.scale, y = frame.y - frame.dy / frame.scale,
        w = renderW / frame.scale, h = renderH / frame.scale }
      if tilted then
        local l, t, r, b = math.huge, math.huge, -math.huge, -math.huge
        local top = math.max(0, frame.horizon + 0.5)
        for _, p in ipairs({ { 0, top }, { renderW, top }, { renderW, renderH }, { 0, renderH } }) do
          local x, y = frame.worldAt(p[1], p[2])
          l, t, r, b = math.min(l, x), math.min(t, y), math.max(r, x), math.max(b, y)
        end
        visible = { x = l, y = t, w = r - l, h = b - t }
      end
      local coverage = {}
      local captureBounds = { x = frame.x, y = frame.y, w = frame.w, h = frame.h }
      for _, rect in ipairs(terrain) do
        local clipped = G.intersection(rect, visible)
        if clipped then
          coverage[#coverage + 1] = clipped
          if connected then
            local r = math.max(captureBounds.x + captureBounds.w, clipped.x + clipped.w)
            local b = math.max(captureBounds.y + captureBounds.h, clipped.y + clipped.h)
            captureBounds.x, captureBounds.y = math.min(captureBounds.x, clipped.x), math.min(captureBounds.y, clipped.y)
            captureBounds.w, captureBounds.h = r - captureBounds.x, b - captureBounds.y
          end
        end
      end
      -- Assemble packed atlas tiles at integer 1:1 coordinates, as vanilla does.
      -- Guard texels cover fractional camera movement before the final crop.
      local captureX, captureY = math.floor(captureBounds.x) - 1, math.floor(captureBounds.y) - 1
      local captureW, captureH = math.ceil(captureBounds.w) + 3, math.ceil(captureBounds.h) + 3
      local nativeFlip = screen and Renderer.mirrorsWorldOverride and Renderer.mirrorsWorldOverride()
      local rasterOK, rasterError = pcall(function()
        if not tilted and not nativeFlip and upright then release(upright); upright = nil end
        ensureRaster(captureW, captureH, tilted or nativeFlip)
        if (tilted or nativeFlip) and not upright then
          upright = lg.newCanvas(renderW, renderH, { dpiscale = 1 })
          upright:setFilter("nearest", "nearest")
        end
      end)
      if not rasterOK then
        if connected then
          presentation.neighborFailure = neighborKey
          warn("neighbor-raster", "Connected scenery exceeds available resources; omitting neighbors "
            .. "without changing the current camera: " .. tostring(rasterError))
          return field(nextDraw, g, w, h, opts)
        end
        if screen then
          failedScreenKey = renderW .. ":" .. renderH
          warn("screen-raster", "Screen camera buffers exceed available resources; keeping the camera in Retro: "
            .. tostring(rasterError))
          clearCanvases()
          release(raster)
          raster, rw, rh = nil, nil, nil
          return field(nextDraw, g, w, h, opts)
        end
        clear()
        fault = true
        warn("raster", "Camera disabled after world raster allocation failure: " .. tostring(rasterError))
        return nextDraw(g, w, h, opts)
      end
      local key = tostring(id) .. ":" .. tostring(layout) .. ":" .. captureW .. ":" .. captureH .. ":" .. tostring(connected)
      for _, entry in ipairs(scopedWorld) do
        key = key .. ":" .. entry.id .. ":" .. tostring(entry.def.midLayout) .. ":" .. entry.ox .. ":" .. entry.oy
      end
      if cacheKey ~= key then clearCache(); cacheKey = key end

      local saved = {}
      local billboard = Field._billboard
      local panX, panY, spans = Field.cameraPanX, Field.cameraPanY, Field.flashSpansFor
      local dirty = Field._nativeDirty
      local world, refresh, sample, neighbors = Map.world, Map.refreshWorld, Map.worldMidAt, Map.neighborList
      for _, k in ipairs(cacheKeys) do saved[k], Field[k] = Field[k], cache[k] end
      if dirty then Field._nativeDirty = true end
      Field.cameraPanX = captureX - math.floor(Player.px + 8 - captureW / 2)
      Field.cameraPanY = captureY - math.floor(Player.py + 8 - captureH / 2)
      Field.flashSpansFor = function(radius, fw, fh)
        return spans(radius, fw, fh, Player.px + 8 - captureX, Player.py + 8 - captureY)
      end
      -- Scope connected-map isolation to this synchronous draw, never simulation.
      Map.world = scopedWorld
      Map.neighborList = {}
      Map.refreshWorld = function() return Map.world end
      if not connected then
        Map.worldMidAt = function(x, y)
          return layout:midAt(x, y), def.pair or layout.pair,
            x < 0 or y < 0 or x >= layout.width or y >= layout.height
        end
      end
      local rendered = pack(pcall(fenced, function()
        lg.setCanvas(raster)
        lg.origin()
        lg.setShader()
        lg.setScissor()
        lg.setBlendMode("alpha", "alphamultiply")
        lg.clear(0, 0, 0, 1)
        lg.setColor(1, 1, 1, 1)
        raster:setFilter("nearest", "nearest")
        presentation.shading.draw(Field, captureX, captureY, layout.width * 16, layout.height * 16,
          neighborShade, number("neighbor_darkness", 60, 0, 100) / 100,
          number("neighbor_distance", 8, 1, 32) * 16, function()
            nextDraw(g, captureW, captureH, tilted and { skipActors = true } or opts)
          end)
        if tilted then
          lg.setCanvas(live)
          lg.origin()
          lg.setShader()
          lg.setScissor()
          lg.setBlendMode("alpha", "premultiplied")
          lg.clear(0, 0, 0, 1)
          lg.setColor(1, 1, 1, 1)
          if backdrop then backdrop.draw(border, frame, renderW, renderH, tiltModules.render, Renderer) end
          for _, rect in ipairs(coverage) do
            tiltModules.render.ground(Renderer, raster, frame, captureX, captureY, captureW, captureH, rect)
          end
          lg.setCanvas(upright)
          lg.clear(0, 0, 0, 0)
          lg.setBlendMode("alpha", "alphamultiply")
          tiltModules.render.actors(Tilt, Field, frame, captureX, captureY, function()
            presentation.shading.draw(Field, captureX, captureY, layout.width * 16, layout.height * 16,
              neighborShade, number("neighbor_darkness", 60, 0, 100) / 100,
              number("neighbor_distance", 8, 1, 32) * 16, function()
                nextDraw(g, captureW, captureH, { actorsOnly = true, billboard = true })
              end)
          end)
          lg.origin()
          lg.setCanvas(live)
          lg.setBlendMode("alpha", "premultiplied")
          lg.setColor(1, 1, 1, 1)
          lg.draw(upright)
        end
      end))
      Map.world, Map.refreshWorld, Map.worldMidAt, Map.neighborList = world, refresh, sample, neighbors
      Field.cameraPanX, Field.cameraPanY, Field.flashSpansFor = panX, panY, spans
      Field._billboard = billboard
      for _, k in ipairs(cacheKeys) do cache[k], Field[k] = Field[k], saved[k] end
      if not rendered[1] then
        fault = true
        clear()
        mod.log:error("Camera rendering failed and was disabled: %s", tostring(rendered[2]))
        error(rendered[2], 0)
      end
      -- Consume the invalidation for our cache, but force vanilla to rebuild
      -- its own batches the next time it renders instead of reusing stale art.
      if dirty then
        Field._nativeDirty = false
        Field._nativeBx, Field._nativeBy = nil, nil
      end
      if not tilted then fenced(function()
        lg.setCanvas(live)
        lg.origin()
        lg.setShader()
        lg.setScissor()
        lg.setBlendMode("alpha", "premultiplied")
        lg.clear(0, 0, 0, 1)
        lg.setColor(1, 1, 1, 1)
        if backdrop then backdrop.draw(border, frame, renderW, renderH) end
        for _, rect in ipairs(coverage) do
          lg.setScissor(frame.dx + (rect.x - frame.x) * frame.scale,
            frame.dy + (rect.y - frame.y) * frame.scale, rect.w * frame.scale, rect.h * frame.scale)
          lg.draw(raster, frame.dx + (captureX - frame.x) * frame.scale,
            frame.dy + (captureY - frame.y) * frame.scale, 0, frame.scale, frame.scale)
        end
      end) end

      local now = love.timer.getTime()
      local kind = choice("transition", "none",
        { none = true, fade = true, slide = true, horizontal = true, vertical = true })
      if kind == "horizontal" or kind == "vertical" then kind = "slide" end
      -- Doors/warps already fade out, load under cover, and fade back in.
      -- Rebase the camera under that cover rather than queue a second effect.
      local battle = BattleTransition.isActive()
      if presentation.previewing or battle or Warp.isBusy() or Fade.isActive() or (Fade.t or 0) > 0 then
        motion = nil
      elseif valid and id ~= area and kind ~= "none" then
        local crossing = presentation.crossing
        local direction = crossing and crossing.from == area and crossing.to == id and crossing.direction
        motion = nil
        if kind == "fade" or direction then
          last, outgoing = outgoing, last
          motion = { start = now, kind = kind, direction = direction,
            duration = number("duration", 350, 50, 2000) / 1000 }
        end
      elseif kind == "none" then motion = nil end
      presentation.crossing = nil
      area = id
      fenced(function()
        lg.setCanvas(last)
        lg.origin()
        lg.setShader()
        lg.setScissor()
        lg.setBlendMode("alpha", "premultiplied")
        lg.clear(0, 0, 0, 1)
        if motion then
          local p = (now - motion.start) / motion.duration
          if p >= 1 then motion = nil
          else
            local a, b = G.mix(motion.kind, p, renderW, renderH, motion.direction)
            paint(outgoing, a)
            paint(live, b)
          end
        end
        if not motion then paint(live, { 0, 0, 1 }) end
      end)
      fenced(function()
        lg.setShader()
        lg.setBlendMode("alpha", "premultiplied")
        -- Keep the engine's low-resolution preview for mirrors/captures; the
        -- main screen uses the native canvas below without this downsample.
        lg.scale(w / renderW, h / renderH)
        paint(last, { 0, 0, 1 })
      end)
      if screen and not battle and not presentation.previewing then
        local output = last
        if nativeFlip then
          -- This is an ordinary LOVE canvas, not a pre-flipped 3D pipeline.
          -- Counter the audited iOS/LOVE 12 override compositor's Y mirror.
          fenced(function()
            lg.setCanvas(upright)
            lg.origin()
            lg.setShader()
            lg.setScissor()
            lg.setBlendMode("alpha", "premultiplied")
            lg.clear(0, 0, 0, 1)
            lg.setColor(1, 1, 1, 1)
            lg.draw(last, 0, renderH, 0, 1, -1)
          end)
          output = upright
        end
        Renderer:setWorldOverride(output)
        published = output
      end
      valid = true
    end

    draw = function(self, ...)
      if detached or not alive() or not compatibility.allowed() then
        detach()
        return oldDraw(self, ...)
      end
      if fault or choice("mode", "normal", { full = true, partial = true, normal = true }) == "normal" then
        clear()
        return oldDraw(self, ...)
      end
      local previous, tiltActive, seen = Field.draw, Tilt.active, false
      presentation.previewDrawn = false
      presentation.previewFieldDraw = previous
      tiltRequested = tiltActive()
      local wrapper = function(...)
        seen = true
        return field(previous, ...)
      end
      Field.draw = wrapper
      -- Compose Tilt ourselves before publishing either resolution. Prevent
      -- Display splitting this field pass or Renderer projecting it a second time.
      Tilt.active = function() return false end
      local r = pack(pcall(oldDraw, self, ...))
      presentation.previewFieldDraw = nil
      if Field.draw == wrapper then Field.draw = previous end
      Tilt.active = tiltActive
      if published and Renderer.worldOverride == published then Renderer:setWorldOverride(nil) end
      published = nil
      if not seen and not presentation.previewDrawn then
        valid, area, motion, presentation.crossing = nil, nil, nil, nil
      end
      return result(r)
    end
    reset = function(self, ...)
      detach()
      return oldReset(self, ...)
    end
    game.draw, game.reset = draw, reset
    return { game = game, dispose = detach,
      crossing = function(event)
        presentation.crossing = nil
        if not capabilities.connections or event.via ~= "connection" or event.fromMapId ~= area then return end
        local source = game.data and game.data.maps and game.data.maps[event.fromMapId]
        local matches, count, direction = {}, 0
        for _, conn in ipairs(Connections.each(source)) do
          if conn.map == event.mapId and not matches[conn.dir] then
            matches[conn.dir], count, direction = true, count + 1, conn.dir
          end
        end
        if count > 1 then
          local facing = Connections.cardinal(Player.facing)
          direction = matches[facing] and facing or nil
        end
        if direction then
          presentation.crossing = { from = event.fromMapId, to = event.mapId, direction = direction }
        end
      end,
      preview = function()
        if detached or fault or not alive() or not compatibility.allowed() or protected()
          or BattleTransition.isActive() then
          return false, "Preview unavailable in this scene."
        end
        if mod.options:get("mode") == "normal" then return false, "Choose FULL or BOUNDED to preview." end
        local session = Session.getSession()
        local def = session and game.data and game.data.maps and game.data.maps[session.map]
        if not def or not def.midLayout then return false, "Enter a map before previewing." end
        local w, h = presentation.viewW or 240, presentation.viewH or 160
        local oldRequested, oldActive = tiltRequested, Tilt.active
        if not presentation.previewDrawn then tiltRequested = oldActive() or tiltRequested end
        presentation.previewing, presentation.previewDrawn = true, true
        Tilt.active = function() return false end
        local r = pack(pcall(fenced, function()
          if type(Renderer.worldViewSize) == "function" then w, h = Renderer:worldViewSize() end
          assert(G.finite(w) and G.finite(h) and w > 0 and h > 0, "Invalid preview viewport")
          lg.origin()
          lg.setShader()
          lg.setScissor()
          lg.setColor(0, 0, 0, 1)
          lg.rectangle("fill", 0, 0, 240, 160)
          local scale = math.min(240 / w, 160 / h)
          lg.translate((240 - w * scale) / 2, (160 - h * scale) / 2)
          lg.scale(scale, scale)
          field(presentation.previewFieldDraw or Field.draw, game, w, h)
        end))
        presentation.previewing, tiltRequested, Tilt.active = false, oldRequested, oldActive
        result(r)
        return true
      end }
  end

  local function dispose()
    if attachment then attachment.dispose(); attachment = nil end
  end
  update = function(nextUpdate, game, dt)
    local r = pack(nextUpdate(game, dt))
    local version = GameVersion.get()
    if not compatibility.allowed() or (version ~= "firered" and version ~= "leafgreen") or not game then dispose()
    elseif not attachment or attachment.game ~= game then
      dispose()
      if type(game.draw) == "function" and type(game.reset) == "function" then
        attachment = bind(game)
      else warn("lifecycle", "Unsupported Static Camera game lifecycle; retaining normal camera.") end
    end
    return unpack(r, 1, r.n)
  end
  mod.hooks:wrap("core.update", update)
  mod.events:on("map.entered", function(event)
    if attachment and compatibility.allowed() then attachment.crossing(event) end
  end)
  mod.hooks:wrap("core.quit_to_launcher", function(nextQuit) dispose(); return nextQuit() end)
  if compatibility.allowed() then
    mod.log:info("Gen 3 camera capability checks passed for engine %s.", compatibility.engine)
  end
  return { draw = function(game)
    if not attachment or attachment.game ~= game then return false, "Start the game before previewing." end
    return attachment.preview()
  end }
end

return Adapter
