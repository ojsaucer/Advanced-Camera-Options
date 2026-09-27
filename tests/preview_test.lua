-- Standalone: use the same Lua runner and tests.modkit as camera_test.lua.
local root = assert(arg[1], "Pass the Static Camera directory")
package.path = package.path .. ";./?.lua;./?/init.lua"
local T = require("tests.modkit")
local Help = assert(loadfile(root .. "\\settings_help.lua"))()
local Runtime = require("src.mods.Runtime")
local Hooks = require("src.mods.Hooks")
local GV = require("src.core.GameVersion")
local Manager = require("src.ui.game3.mod_manager")
local State = require("src.mods.ManagerState")
local Stack = require("src.ui.game3.stack")
local Window = require("src.ui.game3.window")
local Chrome = require("src.ui.game3.chrome")
local Pokedex = require("src.ui.game3.pokedex_chrome")
local Bag = require("src.ui.game3.bag_chrome")
local lg, restores, savedManager = love.graphics, {}, {}
for key, value in pairs(Manager) do savedManager[key] = value end
local function replace(object, key, value)
  local old = object[key]
  restores[#restores + 1] = function() object[key] = old end
  object[key] = value
end
local quit, update
local ok, err = xpcall(function()
  replace(Runtime, "hooks", Hooks.new())
  replace(Runtime, "safeMode", false)
  replace(GV, "current", "firered")
  replace(Stack, "_layers", {})
  Manager.open, Manager._mgr, Manager._game, Manager._prompt = false, nil, nil, nil
  local prints, draws, inputs, writes, calls = {}, 0, 0, 0, 0
  replace(Window, "printPx", function(text) prints[#prints + 1] = text end)
  for _, key in ipairs({ "fixedStdFrame", "userFrame", "cursorPx" }) do
    replace(Window, key, function() end)
  end
  replace(Chrome, "fixedStdFrame", function() end)
  replace(Pokedex, "drawControlInfo", function() end)
  replace(Bag, "drawArrow", function() return true end)
  local drawManager, handleManager = Manager.draw, Manager.handleInput
  replace(Manager, "draw", function(...) draws = draws + 1; return drawManager(...) end)
  replace(Manager, "handleInput", function(...) inputs = inputs + 1; return handleManager(...) end)
  local target, graphicsStack = "ui-240x160", {}
  replace(lg, "getStackDepth", function() return #graphicsStack end)
  replace(lg, "push", function() graphicsStack[#graphicsStack + 1] = target end)
  replace(lg, "pop", function() target = table.remove(graphicsStack) end)
  replace(lg, "getCanvas", function() return target end)
  replace(lg, "setCanvas", function(value) target = value end)
  local schema = {}
  for i = 1, 12 do
    schema[i] = { key = i == 1 and "zoom" or "setting" .. i, type = "number",
      label = "SETTING " .. i, default = 100, min = 5, max = 200, step = 5,
      help = "This is detailed help for this camera setting." }
  end
  schema[12] = { key = "transition", type = "choice", label = "AREA TRANSITION",
    default = "fade", choices = { { "NONE", "none" }, { "FADE", "fade" }, { "SLIDE", "slide" } },
    help = "Choose the camera transition effect." }
  local manifest = { id = "static_camera", name = "Static Camera", enabled = true,
    state = "loaded", version = "0.1.0", category = "qol", profile = "content" }
  local mod = {
    log = { warn = function() end },
    hooks = { wrap = function(_, name, callback)
      Runtime.hooks:wrap(name, callback, 0, "preview_test")
      if name == "core.update" then update = callback else quit = callback end
    end },
  }
  local allowed = true
  local compatibility = { check = function() return true end, allowed = function() return allowed end }
  local events = {}
  local game = {
    reset = function() return "reset", nil, 7 end,
    draw = function() error("preview must not recurse into game.draw") end,
    save = { options = {} },
    writeOptions = function() writes = writes + 1 end,
    mods = {
      optionSchemas = { static_camera = schema },
      modOptions = { static_camera = {} },
      events = { emit = function(_, name, payload) events[#events + 1] = { name = name, payload = payload } end },
      status = function() return { available = { manifest }, errors = {} } end,
    },
  }
  local baseReset, classOptions, renderer = game.reset, State.updateOptions, {}
  local behavior = "ok"
  renderer.draw = function(currentGame)
    T.eq(currentGame, game, "preview receives the real game, not the manager proxy")
    T.eq(lg.getCanvas(), "ui-240x160", "preview renders into the current UI target")
    calls = calls + 1
    if behavior == "unavailable" then return false, "Battle is active. Return to the overworld." end
    if behavior == "empty" then return false end
    lg.setCanvas("renderer-target")
    return true
  end
  Help.start(mod, schema, compatibility, renderer)
  local function tick()
    return Runtime.hooks:call("core.update", function() return "tick", nil, 3 end, game, 0)
  end
  local function input(...)
    local keys = {}
    for i = 1, select("#", ...) do keys[select(i, ...)] = true end
    return { wasPressed = function(_, key) return keys[key] or false end }
  end
  local function press(...) Stack.top().mod.handleInput(input(...)) end
  local function draw()
    prints = {}
    Stack.top().mod.draw()
  end
  local function contains(text)
    return table.concat(prints, " "):find(text, 1, true) ~= nil
  end
  local function show()
    Manager.close()
    Manager.show({ game = game })
    local m = Manager._mgr
    m.currentMod = manifest
    m:openOptions(manifest)
    tick()
    return m, Stack.top()
  end
  Stack.push("paused_underlay", { handleInput = function() error("world received input") end })
  local m, layer = show()
  local moduleDraw, moduleInput = Manager.draw, Manager.handleInput
  local stored = game.mods.modOptions.static_camera
  stored.reverse, stored.unrelated = true, "preserve"
  game.mods.modOptions.other_mod = { transition = "horizontal" }
  m.cursor, m.scroll = 12, 9
  for _, legacy in ipairs({ "horizontal", "vertical" }) do
    stored.transition = legacy
    local before, eventCount = writes, #events
    draw()
    T.eq(stored.transition, "slide", legacy .. " migrates before drawing the choice row")
    T.check(contains("SLIDE"), "the legacy row renders its migrated label, not a misleading default")
    T.eq(writes, before + 1, "migration persists exactly one option change")
    T.eq(#events, eventCount + 1, "migration emits exactly one standard event")
    T.same(events[#events], { name = "mod.options_changed",
      payload = { mod = "static_camera", key = "transition", value = "slide" } },
      "migration uses real manager event payload")
    T.eq(game.save.options.modOptions.static_camera.transition, "slide", "migration reaches the save")
    tick()
    draw()
    T.eq(writes, before + 1, "migration never rewrites an already migrated transition")
    T.eq(stored.reverse, true, "obsolete reverse remains untouched")
    T.eq(stored.unrelated, "preserve", "unrelated options remain untouched")
    T.eq(game.mods.modOptions.other_mod.transition, "horizontal", "other mod values remain untouched")
  end
  for _, value in ipairs({ "none", "fade", "slide", "unknown", false }) do
    stored.transition = value
    local before = writes
    draw()
    tick()
    T.eq(stored.transition, value, "migration changes only the two explicit legacy aliases")
    T.eq(writes, before, "current and unrelated values are never rewritten")
  end
  for _, context in ipairs({ "safe", "mod", "screen", "overlay", "prompt", "covered" }) do
    stored.transition = "vertical"
    local before = writes
    if context == "safe" then Runtime.safeMode = true
    elseif context == "mod" then m.currentMod = { id = "other_mod" }
    elseif context == "screen" then m.screen = "detail"
    elseif context == "overlay" then m.overlay = { kind = "notice", lines = {} }
    elseif context == "prompt" then Manager._prompt = { kind = "qty", value = 1, max = 3 }
    else Stack.push("covered", {}) end
    tick()
    layer.mod.draw()
    T.eq(stored.transition, "vertical", context .. " context blocks legacy migration")
    T.eq(writes, before, context .. " context never persists legacy migration")
    Runtime.safeMode, m.currentMod, m.screen, m.overlay, Manager._prompt = false, manifest, "options", nil, nil
    if context == "covered" then Stack.pop("covered") end
  end
  tick()
  T.eq(stored.transition, "slide", "migration resumes when the options context becomes eligible")
  m.cursor, m.scroll = 8, 5
  draw()
  T.check(contains("Start:PREVIEW") and contains("Select:HELP"), "only camera options advertise both controls")
  local layers, depth, beforeWrites = Stack._layers, Stack.depth(), writes
  local fullscreen, hideBelow, drawUnder = layer.fullscreen, layer.hideBelow, layer.drawUnder
  press("start", "right", "a")
  T.eq(calls, 0, "opening preview does not draw or cache a snapshot during update")
  local beforeDraws, beforeInputs = draws, inputs
  for _ = 1, 3 do
    press("up", "down", "left", "right", "a", "select", "start")
    m:updateOptions(input("right", "a", "select", "start"))
    tick()
    draw()
  end
  T.eq(calls, 3, "every preview draw freshly invokes the camera renderer")
  T.eq(draws, beforeDraws, "preview replaces fullscreen manager drawing")
  T.eq(inputs, beforeInputs, "preview never forwards input to the manager")
  T.eq(writes, beforeWrites, "preview cannot change saved settings")
  T.eq(m.cursor, 8, "preview retains exact cursor")
  T.eq(m.scroll, 5, "preview retains exact scroll")
  T.eq(Stack._layers, layers, "preview preserves stack identity")
  T.eq(Stack.depth(), depth, "preview never adds or removes stack membership")
  T.eq(Stack.top(), layer, "preview uses the original manager layer")
  T.check(Stack.fullscreen(), "engine continues pausing the world behind fullscreen manager")
  T.eq(layer.fullscreen, fullscreen, "fullscreen flag is unchanged")
  T.eq(layer.hideBelow, hideBelow, "hideBelow flag is unchanged")
  T.eq(layer.drawUnder, drawUnder, "drawUnder flag is unchanged")
  T.eq(lg.getCanvas(), "ui-240x160", "callback canvas changes are restored")
  T.eq(lg.getStackDepth(), 0, "callback graphics state is balanced")
  T.check(contains("B:BACK") and not contains("Start:PREVIEW"), "preview has a small return hint only")
  press("b", "right", "a")
  draw()
  T.eq(calls, 3, "B returns without another preview render")
  T.eq(draws, beforeDraws + 1, "B restores actual options drawing")
  T.eq(m.screen, "options", "B retains exact options page")
  T.eq(m.cursor, 8, "B does not navigate the options cursor")
  T.eq(m.scroll, 5, "B does not navigate the options scroll")
  T.eq(writes, beforeWrites, "B consumes simultaneous setting input")
  press("right")
  T.eq(writes, beforeWrites + 1, "normal option editing resumes after B")
  game.mods.modOptions.static_camera.zoom = 800
  stored.transition = "horizontal"
  beforeWrites = writes
  press("start")
  tick()
  T.eq(writes, beforeWrites, "preview suspends normalization as well as setting edits")
  T.eq(stored.transition, "horizontal", "preview does not silently migrate saved transitions")
  press("b")
  tick()
  T.eq(game.mods.modOptions.static_camera.zoom, 200, "normal normalization resumes after preview")
  T.eq(stored.transition, "slide", "transition migration resumes after preview")

  behavior = "unavailable"
  press("start")
  draw()
  T.check(contains("PREVIEW UNAVAILABLE") and contains("Battle is active."),
    "unsupported contexts show the renderer's meaningful reason")
  T.check(contains("B:BACK"), "unavailable preview is dismissible")
  behavior = "empty"
  draw()
  T.check(contains("current game context"), "missing reason gets an honest fallback")
  press("b")
  behavior = "ok"
  Runtime.safeMode = true
  local beforeCalls = calls
  press("start")
  draw()
  T.eq(calls, beforeCalls, "safe mode never invokes the camera renderer")
  T.check(contains("safe mode"), "safe mode explains why preview is unavailable")
  press("b")
  Runtime.safeMode = false
  press("start")
  Runtime.safeMode = true
  draw()
  T.eq(calls, beforeCalls, "entering safe mode also blocks an already-open preview")
  press("b")
  Runtime.safeMode = false
  renderer.draw = nil
  press("start")
  draw()
  T.check(contains("renderer is unavailable"), "missing optional renderer is diagnosed")
  press("b")
  renderer.draw = function() calls = calls + 1; return true end

  m.currentMod = { id = "other_mod" }
  draw()
  T.check(not contains("Start:PREVIEW"), "other mods never advertise preview")
  press("start")
  draw()
  T.eq(calls, beforeCalls, "other mod pages cannot invoke preview")
  m.currentMod = manifest
  m.overlay = { kind = "notice", lines = { "BUSY" } }
  press("start")
  draw()
  T.check(not contains("Start:PREVIEW"), "stock overlays block preview hints")
  m.overlay = nil
  Manager._prompt = { kind = "qty", value = 1, max = 3 }
  press("start")
  draw()
  T.check(not contains("Start:PREVIEW"), "quantity prompts block preview")
  Manager._prompt = nil
  press("select")
  T.eq(Stack.top().id, "static_camera_settings_help", "Select still opens scoped help")
  press("start")
  T.eq(Stack.top().id, "static_camera_settings_help", "Start cannot nest preview inside help")
  press("b")
  T.eq(calls, beforeCalls, "prompts and help never render preview")
  m.screen = "detail"
  draw()
  T.check(not contains("Start:PREVIEW"), "detail pages never advertise preview")
  m.screen = "options"

  for _, change in ipairs({ "screen", "mod", "overlay", "prompt", "layer" }) do
    press("start")
    if change == "screen" then m.screen = "detail"
    elseif change == "mod" then m.currentMod = { id = "other_mod" }
    elseif change == "overlay" then m.overlay = { kind = "notice", lines = {} }
    elseif change == "prompt" then Manager._prompt = { kind = "qty", value = 1, max = 3 }
    else Stack.push("interrupt", {}) end
    tick()
    m.screen, m.currentMod, m.overlay, Manager._prompt = "options", manifest, nil, nil
    if change == "layer" then Stack.pop("interrupt") end
    draw()
    T.eq(calls, beforeCalls, change .. " change closes preview permanently")
  end
  for _, reason in ipairs({ "reset", "quit", "close", "manager", "owner", "version", "compatibility", "update-error" }) do
    press("start")
    local proxy = layer.mod
    if reason == "reset" then
      local a, b, c = game:reset()
      T.check(a == "reset" and b == nil and c == 7, "reset return arity is preserved")
    elseif reason == "quit" then quit(function() end)
    elseif reason == "close" then Manager.close(); tick()
    elseif reason == "manager" then
      Manager._mgr = {}
      proxy.handleInput(input("b"))
      Manager._mgr = m
    elseif reason == "owner" then Runtime.hooks:removeOwner("preview_test"); proxy.draw()
    elseif reason == "version" then GV.current = "red"; tick(); GV.current = "firered"
    elseif reason == "compatibility" then allowed = false; tick(); allowed = true
    else
      T.raises(function() update(function() error("update failed") end, game, 0) end,
        "update failed", "update failures propagate")
    end
    T.eq(m.updateOptions, classOptions, reason .. " detaches instance options wrapper")
    T.eq(layer.mod, Manager, reason .. " restores original manager layer")
    T.eq(game.reset, baseReset, reason .. " restores reset")
    if reason == "owner" then Runtime.hooks:wrap("core.update", update, 0, "preview_test") end
    m, layer = show()
    draw()
    T.eq(calls, beforeCalls, reason .. " cannot resurrect old preview")
  end
  renderer.draw = function()
    lg.push("all")
    lg.setCanvas("leaked-on-error")
    error("injected preview draw error")
  end
  press("start")
  T.raises(draw, "injected preview draw error", "draw errors propagate after cleanup")
  T.eq(lg.getCanvas(), "ui-240x160", "draw failure restores the UI render target")
  T.eq(lg.getStackDepth(), 0, "draw failure unwinds leaked callback graphics state")
  T.eq(layer.mod, Manager, "draw failure restores the original manager")
  T.eq(m.updateOptions, classOptions, "draw failure removes options interception")
  T.eq(game.reset, baseReset, "draw failure restores reset lifecycle")
  tick()
  T.eq(layer.mod, Manager, "failed renderer cannot reattach to a retired manager")
  m, layer = show()
  renderer.draw = function() return true end
  press("start")
  local printLine = Window.printPx
  Window.printPx = function() error("preview hint failed") end
  T.raises(draw, "preview hint failed", "preview chrome errors also propagate")
  Window.printPx = printLine
  T.eq(layer.mod, Manager, "preview chrome failure restores manager drawing and input")
  T.eq(m.updateOptions, classOptions, "preview chrome failure cleans up options interception")
  T.eq(State.updateOptions, classOptions, "ManagerState class is untouched")
  T.eq(Manager.draw, moduleDraw, "global manager drawing is untouched")
  T.eq(Manager.handleInput, moduleInput, "global manager input is untouched")
end, debug.traceback)
if quit then pcall(quit, function() end) end
for i = #restores, 1, -1 do restores[i]() end
for key in pairs(Manager) do Manager[key] = nil end
for key, value in pairs(savedManager) do Manager[key] = value end
if not ok then error(err, 0) end
T.finish("static-camera-preview")
