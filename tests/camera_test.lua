-- Run with 0.3.19 engine modules and the upstream tests.modkit harness.
local root = assert(arg[1], "Pass the Static Camera directory")
package.path = package.path .. ";./?.lua;./?/init.lua"
local T = require("tests.modkit")
-- adapter_gen3.lua rounds the assembled native-raster capture size up to a
-- stable step so connected-neighbor overlap and per-frame player tracking
-- don't force a full canvas/sprite-batch rebuild on every tiny fluctuation.
-- Every exact seen.w/seen.h assertion below reflects that same rounding,
-- reusing the adapter's own helper so the tests can never drift from it.
local roundUpCapture = assert(loadfile(root .. "\\adapter_gen3.lua"))().roundUpCapture
local files = {}
for _, name in ipairs({ "manifest.json", "main.lua", "geometry.lua", "adapter_gen3.lua",
  "settings_help.lua", "tilt_geometry.lua", "tilt_render.lua", "void_backdrop.lua", "scenery_patterns.lua", "boundary_shading.lua",
  "compatibility.lua" }) do
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

for _, base in ipairs({ 1, 3 }) do
  for _, b in ipairs({ { x = 32, y = 48, w = 32, h = 32 },
    { x = 16, y = 32, w = 32, h = 640 }, { x = 16, y = 32, w = 640, h = 32 },
    { x = 0, y = 0, w = 640, h = 480 } }) do
    for _, cap in ipairs({ 0.05, 0.5, 1, 2 }) do
      for _, pos in ipairs({ -1000, 1000 }) do
        local f = G.project(b, 240 * base, 160 * base, pos, pos, "partial", 2, base, base * cap)
        T.check(f.scale <= base * cap, "Bounded maximum overrides boundary and requested zoom")
        T.check(f.x >= b.x and f.y >= b.y and f.x + f.w <= b.x + b.w + 1e-7
          and f.y + f.h <= b.y + b.h + 1e-7, "capped raster stays within authored bounds")
        if b.w * f.scale < 240 * base then
          T.eq(f.x, b.x, "undersized horizontal axis uses the whole room")
          T.eq(f.dx, (240 * base - b.w * f.scale) / 2, "room gets centered horizontal backdrop")
        end
        if b.h * f.scale < 160 * base then
          T.eq(f.y, b.y, "undersized vertical axis uses the whole room")
          T.eq(f.dy, (160 * base - b.h * f.scale) / 2, "room gets centered vertical backdrop")
        end
      end
      T.same(G.project(b, 240, 160, 0, 0, "full", 2, base, base * cap),
        G.project(b, 240, 160, 0, 0, "full", 2, base), "maximum zoom does not affect Full")
    end
  end
end
T.raises(function()
  G.project({ x = 0, y = 0, w = 32, h = 32 }, 240, 160, 0, 0, "partial", 1, 1, 0)
end, "maximum scale", "invalid cap is diagnosed")

for _, b in ipairs({ { x = 32, y = 48, w = 960, h = 160 },
  { x = 32, y = 48, w = 160, h = 960 }, { x = 32, y = 48, w = 480, h = 320 } }) do
  for _, v in ipairs({ { 240, 160 }, { 160, 240 }, { 720, 480 } }) do
    local full = G.project(b, v[1], v[2], 0, 0, "full", 1)
    for _, zoom in ipairs({ 1, 1.05, 1.5, 2 }) do
      for _, fraction in ipairs({ 0, 0.25, 0.5, 0.75, 1 }) do
        local px, py = b.x + (b.w - 16) * fraction, b.y + (b.h - 16) * fraction
        local f = G.project(b, v[1], v[2], px, py, "hybrid", zoom, 9, 0.05)
        T.eq(f.scale, full.scale * zoom, "Hybrid zoom is relative to Full, never Bounded basis/ceiling")
        local vx, vy = f.x - f.dx / f.scale, f.y - f.dy / f.scale
        T.check(f.w > 0 and f.h > 0 and f.x >= b.x and f.y >= b.y
          and f.x + f.w <= b.x + b.w + 1e-7 and f.y + f.h <= b.y + b.h + 1e-7,
          "Hybrid captures only the valid primary intersection")
        for _, a in ipairs({ { f.constrainX, vx, v[1], b.x, b.w, px },
          { f.constrainY, vy, v[2], b.y, b.h, py } }) do
          if a[1] then
            T.check(a[2] >= a[4] - 1e-7 and a[2] + a[3] / f.scale <= a[4] + a[5] + 1e-7,
              "Hybrid constrains the Full edge-touching axis")
            if zoom == 1 then T.check(math.abs(a[2] - a[4]) < 1e-7, "100% constrained axis stays centered") end
          else
            T.check(math.abs(a[2] + a[3] / f.scale / 2 - a[6] - 8) < 1e-7,
              "Hybrid freely follows player on the other axis")
          end
        end
      end
    end
  end
end
local tie = G.project({ x = 0, y = 0, w = 480, h = 320 }, 240, 160, 0, 0, "hybrid", 2)
T.check(tie.constrainX and tie.constrainY, "Hybrid constrains both axes for a tied Full fit")

for _, b in ipairs({ { x = 32, y = 48, w = 960, h = 160 }, { x = 32, y = 48, w = 160, h = 960 },
  { x = 32, y = 48, w = 480, h = 320 } }) do
  for _, v in ipairs({ { 240, 160 }, { 720, 480 } }) do
    local rx, ry = b.w / v[1], b.h / v[2]
    local tolerance = 1e-7 * math.max(rx, ry)
    -- The axis Full already fit without slack (limiting) is the one Scroll
    -- instead scrolls; the other (Full's slack/backdrop axis) stays locked.
    local scrollsX, scrollsY = rx >= ry - tolerance, ry >= rx - tolerance
    for _, fraction in ipairs({ 0, 0.5, 1 }) do
      local px, py = b.x + (b.w - 16) * fraction, b.y + (b.h - 16) * fraction
      local f = G.project(b, v[1], v[2], px, py, "scroll", 1)
      T.eq(f.scale, math.max(v[1] / b.w, v[2] / b.h),
        "Full-Scroll zooms in to exactly fit whichever axis Full left slack on")
      T.check(f.w <= b.w + 1e-7 and f.h <= b.h + 1e-7 and f.x >= b.x - 1e-7 and f.y >= b.y - 1e-7
        and f.x + f.w <= b.x + b.w + 1e-7 and f.y + f.h <= b.y + b.h + 1e-7,
        "Full-Scroll never reveals anything past the area's own bounds")
      if scrollsX and scrollsY then
        T.check(f.constrainX and f.constrainY, "Full-Scroll keeps both axes stationary on an exact tie")
      elseif scrollsX then
        T.check(not f.constrainX and f.constrainY,
          "Full-Scroll scrolls Full's own edge-touching axis, not the slack one")
        T.check(f.w < b.w - 1e-7, "Full-Scroll's scrolling axis has genuine room to move")
        T.check(math.abs(f.h - b.h) < 1e-7, "Full-Scroll's locked axis exactly fits the area")
      else
        T.check(not f.constrainY and f.constrainX,
          "Full-Scroll scrolls Full's own edge-touching axis, not the slack one")
        T.check(f.h < b.h - 1e-7, "Full-Scroll's scrolling axis has genuine room to move")
        T.check(math.abs(f.w - b.w) < 1e-7, "Full-Scroll's locked axis exactly fits the area")
      end
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

for _, kind in ipairs({ "fade", "slide" }) do
  for _, direction in ipairs({ "east", "west", "north", "south" }) do
    local a, b = G.mix(kind, 0, 240, 160, direction)
    T.eq(a[1] + a[2], 0, "transition starts at old frame")
    a, b = G.mix(kind, 1, 240, 160, direction)
    T.eq(b[1] + b[2], 0, "transition ends at new frame")
    a, b = G.mix(kind, 0.5, 240, 160, direction)
    if kind == "fade" then T.eq(a[3] + b[3], 0, "black midpoint")
    elseif direction == "east" or direction == "west" then T.eq(math.abs(a[1] - b[1]), 240, "horizontal seam")
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
local nativeBattle = require("src.core.game3.battle_transition")
local nativeWorldSample = Map.worldMidAt
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
local FieldWeather = require("src.core.game3.field_weather")
FieldWeather._assets = {}
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
  hasMid = function() return true end,
  get = function() return native end, slotFor = function() return 0 end,
  quad = function() return native.testQuad or quad end,
  overQuad = function() return native.testOverQuad end })
stub("src.core.game3.tileset_anim", { setVisiblePairs = function() end })
require("src.import.gba.versions").NATIVE_RENDER = true
local seen = {}
local function crossing(game, destination, direction)
  local source = RT.session.map
  local def = game.data.maps[source]
  local previous = def.connections
  def.connections = { { dir = direction, map = destination, offset = 0 } }
  MR.emit("map.entered", { mapId = destination, fromMapId = source, via = "connection" })
  def.connections = previous
end
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

-- Older engines predate Emerald support entirely; only exercise it when the
-- running engine's own GameVersion table actually knows the id.
local versions = { "firered", "leafgreen" }
if GV.VERSIONS and GV.VERSIONS.emerald then versions[#versions + 1] = "emerald" end
for _, version in ipairs(versions) do
  GV.current = version
  local run = T.sdk.loadMod("mods/static_camera", {
    fs = T.sdk.memfs(files), data = T.sdk.gen3Data(), generation = 3,
  })
  T.eq(#run.errors, 0, version .. " real loader accepts entry: " .. tostring(run.errors[1]))
  T.check(run.loader.exports.static_camera ~= nil, "entry actually executed")
  T.eq(#(run.loader.optionSchemas.static_camera or {}), 17, "seventeen settings registered")
  local rows, byKey, keys = run.loader.optionSchemas.static_camera, {}, {}
  for _, row in ipairs(rows) do
    byKey[row.key], keys[#keys + 1] = row, row.key
    T.check(#row.label <= 18, "setting label fits FRLG menu")
    T.check(type(row.help) == "string" and #row.help > 90, "every setting has detailed help")
    for _, choice in ipairs(row.choices or {}) do
      T.check(#choice[1] <= 8, "choice label fits FRLG menu")
    end
  end
  T.same(keys, { "mode", "connected", "neighbor_shade", "neighbor_darkness", "neighbor_distance",
    "hybrid_zoom", "zoom_style", "zoom", "max_zoom", "framing", "padding", "resolution", "screen_filter",
    "void_fill", "transition", "duration", "experimental" },
    "Full settings precede Bounded settings, followed by shared settings")
  T.eq(byKey.resolution.default, "retro", "existing visual style remains the default")
  T.eq(byKey.screen_filter.default, "crisp", "SCREEN smoothing is opt-in")
  T.same(byKey.screen_filter.choices, { { "CRISP", "crisp" }, { "SMOOTH", "smooth" } },
    "SCREEN filter offers hard pixels or minification smoothing")
  T.eq(byKey.void_fill.default, "black", "black margins remain the safe default")
  T.eq(byKey.zoom_style.default, "consistent", "consistent zoom is default")
  T.eq(byKey.mode.choices[2][2], "scroll", "Full-Scroll is a distinct mode between Full and Hybrid")
  T.eq(byKey.mode.choices[3][2], "hybrid", "Hybrid is a distinct mode between Full-Scroll and Bounded")
  T.eq(byKey.hybrid_zoom.default, 100, "Hybrid starts at Full scale")
  T.eq(byKey.hybrid_zoom.min, 100, "Hybrid only zooms in")
  T.eq(byKey.hybrid_zoom.max, 200, "Hybrid maximum matches the existing zoom range")
  T.eq(byKey.hybrid_zoom.step, 5, "Hybrid zoom uses five percent steps")
  T.eq(byKey.zoom.min, 5, "5 percent minimum")
  T.eq(byKey.zoom.max, 200, "200 percent maximum")
  T.eq(byKey.zoom.step, 5, "5 percent steps")
  T.eq(byKey.max_zoom.default, 0, "zoom ceiling is opt-in")
  T.eq(#byKey.max_zoom.choices, 41, "ceiling offers OFF plus 5-200 percent in 5 percent steps")
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
  local savedCells, savedPool = F._nativeCellsByPair, F._nativeCellPool
  local cells, pool = { fixture = { "vanilla" } }, { { marker = "vanilla" } }
  F._nativeCellsByPair, F._nativeCellPool = cells, pool
  lg.setCanvas(sentinel)
  local x, y, z = game:draw()
  T.eq(x, "draw", "return value")
  T.eq(z, 7, "nil-containing tuple")
  T.eq(seen.w, roundUpCapture(643), "actual FieldView full width plus raster guards")
  T.eq(seen.h, roundUpCapture(483), "actual FieldView full height plus raster guards")
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
  T.eq(F._nativeCellsByPair, cells, "native cell lists restored after mod render")
  T.eq(F._nativeCellPool, pool, "native cell pool restored after mod render")
  T.eq(cells.fixture[1], "vanilla", "vanilla cell list contents untouched")
  T.eq(pool[1].marker, "vanilla", "vanilla pool contents untouched")
  F._nativeCellsByPair, F._nativeCellPool = savedCells, savedPool
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
  T.eq(seen.w, roundUpCapture(115), "setting switches to tighter crop plus guards")
  T.eq(seen.h, roundUpCapture(99), "crop excludes exterior decoration plus guards")
  local pan = seen.panX
  P.px = 96
  game:draw()
  T.eq(seen.w, roundUpCapture(115), "walking keeps crop fixed")
  T.eq(seen.panX - pan, -16, "cancels player following")
  P.px = 80
  settings.padding = 1
  game:draw()
  T.eq(seen.w, roundUpCapture(147), "crop padding setting applied")
  settings.framing = "scene"
  game:draw()
  T.eq(seen.w, roundUpCapture(643), "full-scene toggle restores authored bounds plus guards")
  settings.mode = "partial"
  game:draw()
  T.eq(seen.w, roundUpCapture(123), "default consistent 200 percent captures half normal width plus guards")
  settings.zoom = 100
  game:draw()
  T.eq(seen.w, roundUpCapture(243), "consistent 100 percent matches normal logical scale plus guards")
  settings.zoom = 50
  game:draw()
  T.eq(seen.w, roundUpCapture(483), "consistent 50 percent shows twice normal width plus guards")
  settings.zoom = 5
  game:draw()
  T.eq(seen.w, roundUpCapture(643), "5 percent stops at area boundary plus cropped-out guards")
  settings.zoom = 800
  game:draw()
  T.eq(seen.w, roundUpCapture(123), "legacy 800 percent is capped to 200 percent")
  settings.zoom = 1
  game:draw()
  T.eq(seen.w, roundUpCapture(643), "legacy subminimum is clamped upward, not reset to close zoom")
  settings.zoom_style, settings.zoom = "relative", 200
  game:draw()
  T.eq(seen.w, roundUpCapture(363), "area-relative toggle preserves previous fit-based zoom plus guards")
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
  local hybridX, hybridY = P.px, P.py
  settings.mode, settings.max_zoom = "hybrid", 5
  for _, value in ipairs({ 100, 150, 200, 1, 800, 128, "invalid" }) do
    settings.hybrid_zoom = value
    local expectedZoom = type(value) == "number" and math.max(100, math.min(200,
      math.floor(value / 5 + 0.5) * 5)) / 100 or 1
    for _, px in ipairs({ 80, 96 }) do
      P.px = px
      game:draw()
      local f = G.project({ x = 0, y = 0, w = 640, h = 480 }, 240, 160,
        P.px, P.py, "hybrid", expectedZoom)
      T.eq(seen.w, roundUpCapture(math.ceil(f.w) + 3), "Hybrid renderer captures moving primary width with guards")
      T.eq(seen.h, roundUpCapture(math.ceil(f.h) + 3), "Hybrid renderer captures moving primary height with guards")
      T.eq(seen.panX, math.floor(f.x) - 1 - math.floor(P.px + 8 - seen.w / 2),
        "Hybrid native capture alignment follows player without mutating position")
    end
  end
  P.px, P.py = hybridX, hybridY
  settings.hybrid_zoom, settings.max_zoom = 100, 0
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
      crossing(game, "SECOND", effect == "vertical" and "south" or "east")
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
    crossing = crossing,
    nativeBattle = nativeBattle, worldSample = nativeWorldSample,
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
GV.current = "firered"
assert(loadfile(root .. "\\tests\\settings_help_test.lua"))()({ T = T, root = root })
assert(loadfile(root .. "\\tests\\boundary_shading_test.lua"))()({ T = T, root = root })
assert(loadfile(root .. "\\tests\\scenery_patterns_test.lua"))()({ T = T, root = root })
if not love._staticCameraGpu then
  assert(loadfile(root .. "\\tests\\tilt_test.lua"))()({ T = T, root = root })
  assert(loadfile(root .. "\\tests\\void_fill_test.lua"))()({ T = T, root = root })
end
assert(loadfile(root .. "\\tests\\compatibility_test.lua"))()({ T = T, root = root, def = def, files = files })
if love._staticCameraGpu then
  assert(loadfile(root .. "\\tests\\extrude_test.lua"))()({ root = root })
end
T.finish("Static Camera")
