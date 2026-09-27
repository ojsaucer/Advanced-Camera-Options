return function(ctx)
  local T, root = ctx.T, ctx.root
  local C = assert(loadfile(root .. "\\compatibility.lua"))()
  local Version = require("src.core.Version")
  local Runtime = require("src.mods.Runtime")
  local Hooks = require("src.mods.Hooks")
  local Field = require("src.core.game3.field_view")
  local Tilt = require("src.render.Tilt")
  local Renderer = require("src.render.Renderer")
  local Stack = require("src.ui.game3.stack")
  local Collision = require("src.core.game3.collision")
  local Native = require("src.core.game3.tileset_native")
  local GameVersion = require("src.core.GameVersion")
  local Session = require("src.core.game3.runtime")
  local engine, api, hooks, gameVersion = Version.engine, Version.modApi, Runtime.hooks, GameVersion.current
  local settings, warnings, schema, quit
  local function reset()
    if quit then quit(function() end); quit = nil end
    Runtime.hooks = Hooks.new()
    settings, warnings, schema = {}, {}, nil
  end
  local mod = {
    events = { on = function(_, _, callback) return callback end },
    options = {
      define = function(_, rows)
        schema = rows
        for _, row in ipairs(rows) do
          if settings[row.key] == nil then settings[row.key] = row.default end
        end
      end,
      get = function(_, key) return settings[key] end,
    },
    log = {
      warn = function(_, format, ...) warnings[#warnings + 1] = string.format(format, ...) end,
      info = function() end,
    },
    hooks = { wrap = function(_, name, callback)
      Runtime.hooks:wrap(name, callback, 0, "compatibility_test")
      if name == "core.quit_to_launcher" then
        local previous = quit
        quit = function(nextQuit)
          callback(function() if previous then previous(nextQuit) else nextQuit() end end)
        end
      end
    end },
    read = function(_, path)
      local file = assert(io.open(root .. "\\" .. path, "rb"))
      local text = file:read("*a")
      file:close()
      return text
    end,
  }
  local function start()
    assert(loadfile(root .. "\\main.lua"))()(mod)
  end
  local function tick(game)
    local a, b, c = Runtime.hooks:call("core.update",
      function() return "tick", nil, 3 end, game, 0)
    T.check(a == "tick" and b == nil and c == 3, "compatibility preserves update return values")
  end
  local restores = {}
  local function replace(object, key, value)
    local old = object[key]
    restores[#restores + 1] = function() object[key] = old end
    object[key] = value
  end
  local function restore()
    for i = #restores, 1, -1 do restores[i]() end
    restores = {}
  end
  local ok, err = xpcall(function()
    reset()
    for _, v in ipairs({ "0.3.19", "0.3.22" }) do
      Version.engine, Version.modApi = v, 2
      T.check(C.new(mod).allowed(), "tested engine works without opt-in: " .. v)
    end
    for _, v in ipairs({ "0.3.20", "0.3.21", "0.3.23", "0.3.999" }) do
      Version.engine, settings.experimental = v, false
      local compatibility = C.new(mod)
      T.check(not compatibility.allowed(), "untested engine defaults to vanilla: " .. v)
      local count = #warnings
      compatibility.allowed()
      T.eq(#warnings, count, "unverified warning is not repeated every update")
      settings.experimental = true
      T.check(compatibility.allowed(), "explicit opt-in admits untested patch: " .. v)
      settings.experimental = false
      T.check(not compatibility.allowed(), "opt-out is effective live")
    end
    for _, v in ipairs({ "0.3.18", "0.4.0", "1.0.0", "0.0.0-dev", "0.3.23-dev", "invalid" }) do
      Version.engine, settings.experimental = v, true
      T.check(not C.new(mod).allowed(), "opt-in cannot bypass engine family: " .. v)
    end
    Version.engine, Version.modApi = "0.3.22", 3
    T.check(not C.new(mod).allowed(), "opt-in cannot bypass API major")
    Version.engine, Version.modApi = engine, api
    for _, group in ipairs({ "camera", "screen", "tilt", "terrain", "backdrop", "shade", "help" }) do
      T.check(C.new(mod).check(group), "real installed module capabilities: " .. group)
    end
    local requiredDraw = Field.draw
    replace(Field, "draw", false)
    T.check(not C.new(mod).check("camera"), "non-callable required method rejected")
    restore()
    replace(package.loaded, "src.core.game3.warp", nil)
    replace(package.preload, "src.core.game3.warp", function() error("injected missing warp module") end)
    local compatibility = C.new(mod)
    T.check(not compatibility.check("camera"), "module load failure disables camera before wrapping")
    T.check(warnings[#warnings]:find("injected missing warp module", 1, true), "module load diagnostic preserved")
    restore()
    T.eq(Field.draw, requiredDraw, "probes do not replace field draw")

    GameVersion.current = "firered"
    local game = { phase = "field", data = { maps = { FIXTURE = ctx.def } },
      draw = function(self) Field.draw(self, 240, 160); return "draw", nil, 7 end,
      reset = function() return "reset" end }
    local baseDraw, baseReset = game.draw, game.reset
    Version.engine = "0.3.23"
    reset()
    local loaded = T.sdk.loadMod("mods/static_camera", {
      fs = T.sdk.memfs(ctx.files), data = T.sdk.gen3Data(), generation = 3,
    })
    T.eq(#loaded.errors, 0, "real loader admits untested patch to expose opt-in")
    T.eq(#(loaded.loader.optionSchemas.static_camera or {}), 12, "real untested loader exposes opt-in setting")
    loaded.release()
    reset()
    start()
    T.eq(#schema, 12, "untested engine still registers all settings")
    T.eq(settings.experimental, false, "experimental option defaults off")
    tick(game)
    T.eq(game.draw, baseDraw, "untested engine has no game wrapper before opt-in")
    settings.experimental = true
    tick(game)
    T.check(game.draw ~= baseDraw, "opt-in installs camera without reboot")
    local sentinel = love.graphics.newCanvas(240, 160)
    local originalCanvas = love.graphics.getCanvas()
    love.graphics.setCanvas(sentinel)
    Session.active, Session.session = true, { map = "FIXTURE" }
    settings.transition = "none"
    local a, b, c = game:draw()
    T.check(a == "draw" and b == nil and c == 7, "experimental adapter actually renders")
    settings.experimental = false
    tick(game)
    T.eq(game.draw, baseDraw, "opt-out restores game draw")
    T.eq(game.reset, baseReset, "opt-out restores game reset")
    T.eq(Renderer.worldOverride, nil, "opt-out leaves no published camera canvas")
    love.graphics.setCanvas(originalCanvas)
    sentinel:release()
    settings.experimental = true
    tick(game)
    T.check(game.draw ~= baseDraw, "re-enabling opt-in reattaches")
    reset()
    T.eq(game.draw, baseDraw, "quit cleans compatibility attachment")
    Version.engine = engine

    replace(Field, "flashSpansFor", nil)
    start()
    tick(game)
    T.eq(game.draw, baseDraw, "missing required field capability preserves vanilla")
    T.check(#warnings > 0, "missing required capability is reported")
    reset()
    restore()

    replace(Stack, "push", nil)
    start()
    T.eq(#(Runtime.hooks.chains["core.update"] or {}), 1, "missing help does not install help hooks")
    tick(game)
    T.check(game.draw ~= baseDraw, "missing help alone does not disable the camera")
    reset()
    restore()

    local FieldWeather = require("src.core.game3.field_weather")
    replace(FieldWeather, "getWeather", nil)
    local compatibility = C.new(mod)
    T.check(not compatibility.check("shade"), "missing shade query disables only backdrop shading")
    T.check(compatibility.check("camera") and compatibility.check("backdrop"),
      "shade API is not required for camera or raw backdrop")
    reset()
    restore()

    -- Exercise real flat rendering while independent optional capabilities are absent.
    replace(Renderer, "setWorldOverride", nil)
    replace(Renderer, "tiltShader", nil)
    replace(Collision, "ledgeLanding", nil)
    replace(Native, "hasMid", nil)
    replace(Stack, "push", nil)
    start()
    settings.resolution, settings.framing, settings.void_fill = "screen", "reachable", "game"
    settings.transition = "none"
    Session.active, Session.session = true, { map = "FIXTURE" }
    replace(Tilt, "active", function() return true end)
    local sentinel = love.graphics.newCanvas(240, 160)
    local originalCanvas = love.graphics.getCanvas()
    love.graphics.setCanvas(sentinel)
    tick(game)
    T.check(game.draw ~= baseDraw, "optional feature failures retain core camera")
    local a, b, c = game:draw()
    T.check(a == "draw" and b == nil and c == 7, "degraded renderer completes normal draw contract")
    T.eq(love.graphics.getCanvas(), sentinel, "degraded camera preserves render target")
    T.eq(Renderer.worldOverride, nil, "missing screen API never publishes an override")
    T.check(#warnings >= 5, "all unavailable optional features report diagnostics")
    reset()
    love.graphics.setCanvas(originalCanvas)
    sentinel:release()
    restore()
    start()
    tick(game)
    T.check(game.draw ~= baseDraw, "restart after capabilities restored enables camera")
    reset()
  end, debug.traceback)
  if quit then quit(function() end) end
  restore()
  Version.engine, Version.modApi, Runtime.hooks, GameVersion.current = engine, api, hooks, gameVersion
  if not ok then error(err, 0) end
end
