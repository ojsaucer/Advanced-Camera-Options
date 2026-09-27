-- Run with 0.3.19 engine modules and the upstream tests.modkit harness.
local root = assert(arg[1], "Pass the Static Camera directory")
package.path = package.path .. ";./?.lua;./?/init.lua"
local T = require("tests.modkit")
local files = {}
for _, name in ipairs({ "manifest.json", "main.lua", "geometry.lua", "adapter_gen3.lua",
  "settings_help.lua", "tilt_geometry.lua", "tilt_render.lua", "void_backdrop.lua" }) do
  local file = assert(io.open(root .. "\\" .. name, "rb"))
  files["mods/static_camera/" .. name] = file:read("*a")
  file:close()
end
local G = assert(loadstring(files["mods/static_camera/geometry.lua"]))()
for _, b in ipairs({ { x = 0, y = 0, w = 640, h = 480 },
  { x = 32, y = 16, w = 128, h = 96 }, { x = 0, y = 0, w = 64, h = 2048 },
  { x = 0, y = 0, w = 2048, h = 64 }, { x = 0, y = 0, w = 16, h = 16 } }) do
  for _, v in ipairs({ { 240, 160 }, { 160, 320 }, { 1024, 128 }, { 320, 180 } }) do
    local full = G.project(b, v[1], v[2], 0, 0, "full", 2)
    T.same(full, G.project(b, v[1], v[2], 9000, -9000, "full", 2), "stationary full")
    T.eq(full.w, b.w, "whole width")
    T.eq(full.h, b.h, "whole height")
    for _, zoom in ipairs({ 1.25, 2, 3.75, 8 }) do
      for _, pos in ipairs({ -1000, 0, 64, 320, 10000 }) do
        local p = G.project(b, v[1], v[2], pos, pos, "partial", zoom)
        T.check(p.x >= b.x - 1e-8 and p.y >= b.y - 1e-8
          and p.x + p.w <= b.x + b.w + 1e-8
          and p.y + p.h <= b.y + b.h + 1e-8, "bounded on both axes")
        T.check(p.scale + 1e-8 >= full.scale * zoom, "closer zoom maintained")
      end
    end
  end
end
T.raises(function() G.project({}, 240, 160, 0, 0, "full", 2) end, "bound", "invalid bounds diagnosed")
T.raises(function() G.project({ x = 0, y = 0, w = 640, h = 480 },
  240, 160, 0, 0, "partial", 1, 0) end, "reference scale", "invalid reference diagnosed")
for _, base in ipairs({ 1, 3, 6 }) do
  for _, zoom in ipairs({ 0.05, 0.25, 0.5, 1, 1.25, 2 }) do
    for _, b in ipairs({ { x = 0, y = 0, w = 640, h = 480 },
      { x = 32, y = 16, w = 1280, h = 960 },
      { x = 16, y = 32, w = 64, h = 96 },
      { x = 32, y = 16, w = 640, h = 32 } }) do
      for _, position in ipairs({ -1000, 100, 10000 }) do
        local p = G.project(b, 240 * base, 160 * base, position, position, "partial", zoom, base)
        T.eq(p.scale, math.max(base * zoom, 240 * base / b.w, 160 * base / b.h),
          "consistent scale is independent of map fit except boundary minimum")
        T.check(p.x >= b.x - 1e-8 and p.y >= b.y - 1e-8
          and p.x + p.w <= b.x + b.w + 1e-8 and p.y + p.h <= b.y + b.h + 1e-8,
          "consistent camera clamps all four edges")
      end
      T.same(G.project(b, 240 * base, 160 * base, 100, 100, "full", zoom, base),
        G.project(b, 240 * base, 160 * base, 100, 100, "full", zoom),
        "zoom reference never changes Full Static")
    end
  end
end

local function room(x, y, d)
  local tx, ty = x + d[1], y + d[2]
  if tx >= 2 and tx <= 5 and ty >= 3 and ty <= 6 then return tx, ty end
end
T.same(G.reachable(12, 12, 3, 4, 0, room), { x = 32, y = 48, w = 64, h = 64 }, "reachable crop")
T.same(G.reachable(12, 12, 3, 4, 1, room), { x = 16, y = 32, w = 96, h = 96 }, "padding")
T.same(G.reachable(2, 2, 0, 0, 4, function() end),
  { x = 0, y = 0, w = 32, h = 32 }, "padding clamped to map")
T.same(G.reachable(3, 1, 0, 0, 0, function(x, y, d)
  if d[3] == "right" and x == 0 then return 2, 0 end
end), { x = 0, y = 0, w = 48, h = 16 }, "directed ledge graph")

for _, kind in ipairs({ "fade", "horizontal", "vertical" }) do
  for _, reverse in ipairs({ false, true }) do
    local a, b = G.mix(kind, 0, 240, 160, reverse)
    T.eq(a[1] + a[2], 0, "transition starts at old frame")
    a, b = G.mix(kind, 1, 240, 160, reverse)
    T.eq(b[1] + b[2], 0, "transition ends at new frame")
    a, b = G.mix(kind, 0.5, 240, 160, reverse)
    if kind == "fade" then T.eq(a[3] + b[3], 0, "black midpoint")
    elseif kind == "horizontal" then T.eq(math.abs(a[1] - b[1]), 240, "horizontal seam")
    else T.eq(math.abs(a[2] - b[2]), 160, "vertical seam") end
  end
end

local lg, depth = love.graphics, 0
local push, pop, batch = lg.push, lg.pop, lg.newSpriteBatch
lg.push = function(...) depth = depth + 1; return push(...) end
lg.pop = function(...) depth = depth - 1; return pop(...) end
lg.getStackDepth = function() return depth end
lg.newSpriteBatch = function(...)
  local b = batch(...)
  if type(b) == "table" then b.release = function(self) self.released = true end end
  return b
end
local now = 0
love.timer.getTime = function() return now end
local GV = require("src.core.GameVersion")
local F = require("src.core.game3.field_view")
local RT = require("src.core.game3.runtime")
local P = require("src.core.game3.player")
local MR = require("src.mods.Runtime")
local Map = require("src.core.game3.map")
local Collision = require("src.core.game3.collision")
local Tilt = require("src.render.Tilt")
local original = F.draw
local function stub(name, value) package.loaded[name] = value end
stub("src.ui.game3.shop_menu", { isShopCamera = function() return false end })
stub("src.ui.game3.seagallop", { isActive = function() return false end })
stub("src.core.game3.camera_object", { isActive = function() return false end })
stub("src.core.game3.battle_transition", { isActive = function() return false end })
stub("src.core.game3.bg", { hasVisible = function() return false end })
stub("src.core.game3.scripting.space", {})
stub("src.core.game3.scripting.interaction_scripts", { behaviors = { fixture = { [0] = 0 } } })
stub("src.core.game3.oam", {})
stub("src.core.game3.field_effects", {})
stub("src.core.game3.doors", {})
stub("src.core.game3.pokecenter_heal", {})
stub("src.core.game3.ss_anne_cutscene", {})
stub("src.core.game3.field_weather", {})
stub("src.core.game3.ow_sprites", { ready = function() return false end })
stub("src.core.game3.objects", { hasMap = function() return false end })
local atlas
if love._staticCameraGpu then
  atlas = love.image.newImageData(16, 16)
  atlas:mapPixel(function() return 0.1, 0.8, 0.2, 1 end)
end
local native = { image = lg.newImage(atlas or "synthetic") }
local quad = lg.newQuad(0, 0, 16, 16, 16, 16)
stub("src.core.game3.tileset_native", { ready = function() return true end,
  get = function() return native end, slotFor = function() return 0 end,
  quad = function() return native.testQuad or quad end,
  overQuad = function() return native.testOverQuad end })
stub("src.core.game3.tileset_anim", { setVisiblePairs = function() end })
require("src.import.gba.versions").NATIVE_RENDER = true
local seen = {}
local vanillaRefresh = function() seen.refresh = (seen.refresh or 0) + 1 end
local vanillaSample = function() return 0, "fixture", false end
Map.refreshWorld, Map.worldMidAt = vanillaRefresh, vanillaSample
local world = { { id = "NEIGHBOR" } }
Map.world = world
local def = { width = 40, height = 30, pair = "fixture", midLayout = {
  width = 40, height = 30, pair = "fixture", midAt = function() return 0 end,
  elevAt = function() return 3 end,
  collAt = function(_, x, y) return x >= 4 and x <= 10 and y >= 4 and y <= 9 and 0 or 7 end,
  collArray = function(self)
    local grid = {}
    for y = 0, self.height - 1 do
      for x = 0, self.width - 1 do grid[#grid + 1] = self:collAt(x, y) end
    end
    return grid
  end,
} }
RT.active, RT.session = true, { map = "FIXTURE" }
P.px, P.py = 80, 96
P.walkPhase, P.drawFlip = function() return 0 end, function() return false end
Collision.bindMap({ data = {} }, "FIXTURE", def)

for _, version in ipairs({ "firered", "leafgreen" }) do
  GV.current = version
  local run = T.sdk.loadMod("mods/static_camera", {
    fs = T.sdk.memfs(files), data = T.sdk.gen3Data(), generation = 3,
  })
  T.eq(#run.errors, 0, version .. " real loader accepts entry: " .. tostring(run.errors[1]))
  T.check(run.loader.exports.static_camera ~= nil, "entry actually executed")
  T.eq(#(run.loader.optionSchemas.static_camera or {}), 10, "ten settings registered")
  local rows, byKey, keys = run.loader.optionSchemas.static_camera, {}, {}
  for _, row in ipairs(rows) do
    byKey[row.key], keys[#keys + 1] = row, row.key
    T.check(#row.label <= 18, "setting label fits FRLG menu")
    T.check(type(row.help) == "string" and #row.help > 90, "every setting has detailed help")
    for _, choice in ipairs(row.choices or {}) do
      T.check(#choice[1] <= 8, "choice label fits FRLG menu")
    end
  end
  T.same(keys, { "mode", "zoom_style", "zoom", "framing", "padding", "resolution",
    "void_fill", "transition", "duration", "reverse" }, "related settings are grouped in order")
  T.eq(byKey.resolution.default, "retro", "existing visual style remains the default")
  T.eq(byKey.void_fill.default, "black", "black margins remain the safe default")
  T.eq(byKey.zoom_style.default, "consistent", "consistent zoom is default")
  T.eq(byKey.zoom.min, 5, "5 percent minimum")
  T.eq(byKey.zoom.max, 200, "200 percent maximum")
  T.eq(byKey.zoom.step, 5, "5 percent steps")
  if #run.errors > 0 then error(table.concat(run.errors, "\n")) end
  local settings = { mode = "full", transition = "none", framing = "scene" }
  run.loader.modOptions.static_camera = settings
  F._flashMapId, F.flashLevel = "FIXTURE", 0
  RT.session.map = "FIXTURE"
  local observer = function(g, w, h, opts)
    seen.w, seen.h = w, h
    seen.panX, seen.panY = F.cameraPanX, F.cameraPanY
    seen.world = Map.world
    return original(g, w, h, opts)
  end
  F.draw = observer
  local game = { phase = "field", data = { maps = { FIXTURE = def, SECOND = def } },
    update = function() end, reset = function() return "reset" end }
  game.draw = function(self) F.draw(self, 240, 160); return "draw", nil, 7 end
  local baseDraw, baseReset = game.draw, game.reset
  MR.call("core.update", function(g, dt) g:update(dt) end, game, 1 / 60)
  local tiltActive = Tilt.active
  local sentinel = lg.newCanvas(240, 160)
  lg.setCanvas(sentinel)
  local x, y, z = game:draw()
  T.eq(x, "draw", "return value")
  T.eq(z, 7, "nil-containing tuple")
  T.eq(seen.w, 643, "actual FieldView full width plus raster guards")
  T.eq(seen.h, 483, "actual FieldView full height plus raster guards")
  T.eq(#seen.world, 1, "no adjacent maps during rendering")
  T.eq(seen.world[1].id, "FIXTURE", "current map only")
  T.eq(Map.world, world, "connected world restored")
  T.eq(Map.refreshWorld, vanillaRefresh, "refresh restored")
  T.eq(Map.worldMidAt, vanillaSample, "sampling restored")
  T.eq(P.px, 80, "player position not mutated")
  T.eq(F.draw, observer, "temporary wrapper restored")
  T.eq(Tilt.active, tiltActive, "tilt preference restored")
  T.eq(lg.getCanvas(), sentinel, "render target restored")
  T.eq(depth, 0, "graphics stack balanced")
  if love._staticCameraGpu then
    lg.setCanvas()
    local pixels = sentinel:newImageData()
    local r, green, b = pixels:getPixel(0, 80)
    T.check(r < 0.01 and green < 0.01 and b < 0.01, "GPU: Full Static margin is black")
    r, green, b = pixels:getPixel(180, 100)
    T.check(green > 0.7 and r < 0.2, "GPU: terrain is rendered into fitted frame")
    pixels:release()
    lg.setCanvas(sentinel)
  end
  settings.framing, settings.padding = "reachable", 0
  game:draw()
  T.eq(seen.w, 115, "setting switches to tighter crop plus guards")
  T.eq(seen.h, 99, "crop excludes exterior decoration plus guards")
  local pan = seen.panX
  P.px = 96
  game:draw()
  T.eq(seen.w, 115, "walking keeps crop fixed")
  T.eq(seen.panX - pan, -16, "cancels player following")
  P.px = 80
  settings.padding = 1
  game:draw()
  T.eq(seen.w, 147, "crop padding setting applied")
  settings.framing = "scene"
  game:draw()
  T.eq(seen.w, 643, "full-scene toggle restores authored bounds plus guards")
  settings.mode = "partial"
  game:draw()
  T.eq(seen.w, 123, "default consistent 200 percent captures half normal width plus guards")
  settings.zoom = 100
  game:draw()
  T.eq(seen.w, 243, "consistent 100 percent matches normal logical scale plus guards")
  settings.zoom = 50
  game:draw()
  T.eq(seen.w, 483, "consistent 50 percent shows twice normal width plus guards")
  settings.zoom = 5
  game:draw()
  T.eq(seen.w, 643, "5 percent stops at area boundary plus cropped-out guards")
  settings.zoom = 800
  game:draw()
  T.eq(seen.w, 123, "legacy 800 percent is capped to 200 percent")
  settings.zoom = 1
  game:draw()
  T.eq(seen.w, 643, "legacy subminimum is clamped upward, not reset to close zoom")
  settings.zoom_style, settings.zoom = "relative", 200
  game:draw()
  T.eq(seen.w, 363, "area-relative toggle preserves previous fit-based zoom plus guards")
  settings.zoom_style = "consistent"
  game:draw()
  T.check(seen.w < 640 and seen.h < 480, "closer bounded render")
  if love._staticCameraGpu then
    lg.setCanvas()
    local pixels = sentinel:newImageData()
    local r, green = pixels:getPixel(0, 0)
    T.check(green > 0.7 and r < 0.2, "GPU: Partial fills the viewport without void")
    pixels:release()
    lg.setCanvas(sentinel)
  end
  settings.mode = "normal"
  game:draw()
  T.eq(seen.w, 240, "Normal uses original viewport")
  T.eq(seen.panX, 0, "Normal original camera pan")

  settings.mode, settings.transition = "full", "fade"
  now = 1
  game:draw()
  RT.session.map, F._flashMapId = "SECOND", "SECOND"
  now = 2
  game:draw()
  now = 2.175
  game:draw()
  if love._staticCameraGpu then
    lg.setCanvas()
    local pixels = sentinel:newImageData()
    local r, green, b = pixels:getPixel(180, 100)
    T.check(r < 0.01 and green < 0.01 and b < 0.01, "GPU: fade midpoint is black")
    pixels:release()
    lg.setCanvas(sentinel)
  end
  now = 2.35
  game:draw()
  T.eq(depth, 0, "real renderer transitions keep stack balanced")
  if love._staticCameraGpu then
    local function colorAt(px, py)
      lg.setCanvas()
      local pixels = sentinel:newImageData()
      local r, green, blue = pixels:getPixel(px, py)
      pixels:release()
      lg.setCanvas(sentinel)
      return r, green, blue
    end
    local greenImage = native.image
    local redPixels = love.image.newImageData(16, 16)
    redPixels:mapPixel(function() return 0.8, 0.1, 0.2, 1 end)
    local redImage = lg.newImage(redPixels)
    for _, effect in ipairs({ "horizontal", "vertical" }) do
      settings.mode = "normal"
      game:draw()
      settings.mode, settings.transition, settings.duration = "partial", effect, 1000
      RT.session.map, F._flashMapId = "FIXTURE", "FIXTURE"
      native.image = greenImage
      now = 10
      game:draw()
      RT.session.map, F._flashMapId, native.image = "SECOND", "SECOND", redImage
      now = 11
      game:draw()
      now = 11.5
      game:draw()
      local r1, g1 = colorAt(20, 20)
      local r2, g2 = colorAt(220, 140)
      T.check(g1 > 0.7 and r1 < 0.2, "GPU: " .. effect .. " outgoing view retained")
      T.check(r2 > 0.7 and g2 < 0.2, "GPU: " .. effect .. " incoming view prepared")
    end
    native.image = greenImage
    redPixels:release()
    -- The adapter's current batch still owns redImage until the next cache clear.
  end

  assert(loadfile(root .. "\\tests\\resolution_test.lua"))()({
    T = T, game = game, settings = settings, native = native,
    sentinel = sentinel, Field = F, Runtime = MR, def = def, seen = seen, root = root,
    setTime = function(value) now = value end,
  })

  -- Force an error inside the wrapped renderer, not a fabricated camera API.
  F.draw = function()
    lg.push("all")
    error("injected drawing failure")
  end
  local failDraw = F.draw
  T.raises(function() game:draw() end, "injected drawing failure", "draw error propagated")
  T.eq(F.draw, failDraw, "error restores original draw method")
  T.eq(Map.world, world, "error restores world")
  T.eq(Map.refreshWorld, vanillaRefresh, "error restores refresh")
  T.eq(F.cameraPanX, 0, "error restores camera pan")
  T.eq(Tilt.active, tiltActive, "error restores tilt")
  T.eq(lg.getCanvas(), sentinel, "error restores canvas")
  T.eq(depth, 0, "error unwinds leaked graphics push")
  F.draw = observer
  MR.hooks:removeOwner("static_camera")
  game:draw()
  T.eq(game.draw, baseDraw, "disable detaches instance wrapper")
  T.eq(game.reset, baseReset, "disable restores reset")
  MR.call("core.update", function() end, game, 0)
  T.eq(game.draw, baseDraw, "removed hook cannot reattach")
  run.release()
  F.draw = original
  lg.setCanvas()
end
assert(loadfile(root .. "\\tests\\settings_help_test.lua"))()({ T = T, root = root })
if not love._staticCameraGpu then
  assert(loadfile(root .. "\\tests\\tilt_test.lua"))()({ T = T, root = root })
  assert(loadfile(root .. "\\tests\\void_fill_test.lua"))()({ T = T, root = root })
end
T.finish("Static Camera 0.8.0")
