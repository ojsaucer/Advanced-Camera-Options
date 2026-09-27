-- Uses the stock ManagerState and FRLG stack; only drawing sinks and game data are synthetic.
return function(ctx)
  local T, root = assert(ctx.T), assert(ctx.root)
  local Runtime = require("src.mods.Runtime")
  local Hooks = require("src.mods.Hooks")
  local GV = require("src.core.GameVersion")
  local Manager = require("src.ui.game3.mod_manager")
  local State = require("src.mods.ManagerState")
  local Stack = require("src.ui.game3.stack")
  local Window = require("src.ui.game3.window")
  local Chrome = require("src.ui.game3.chrome")
  local Font = require("src.ui.game3.frlg_font")
  local Pokedex = require("src.ui.game3.pokedex_chrome")
  local Bag = require("src.ui.game3.bag_chrome")
  local saved, restores = {}, {}
  for k, v in pairs(Manager) do saved[k] = v end
  local function replace(object, key, value)
    local original = object[key]
    restores[#restores + 1] = function() object[key] = original end
    object[key] = value
  end
  local prints, frames = {}, {}
  local classOptions, originalDraw = State.updateOptions, Manager.draw
  local quit, update
  local function cleanup()
    if quit then pcall(quit, function() end) end
    for i = #restores, 1, -1 do restores[i]() end
    for k in pairs(Manager) do Manager[k] = nil end
    for k, v in pairs(saved) do Manager[k] = v end
  end
  local ok, err = xpcall(function()
    replace(Runtime, "hooks", Hooks.new())
    replace(Runtime, "safeMode", false)
    replace(GV, "current", "firered")
    replace(Stack, "_layers", {})
    Manager.open, Manager._mgr, Manager._game, Manager._prompt = false, nil, nil, nil
    replace(Window, "printPx", function(text, x, y, opts)
      prints[#prints + 1] = { text = text, x = x, y = y, width = opts and opts.maxWidth }
    end)
    local function frame(tpl)
      frames[#frames + 1] = { x = tpl.left * 8 - 8, y = tpl.top * 8 - 8,
        w = tpl.w * 8 + 16, h = tpl.h * 8 + 16 }
    end
    replace(Window, "fixedStdFrame", frame)
    replace(Window, "userFrame", frame)
    replace(Window, "cursorPx", function() end)
    replace(Chrome, "fixedStdFrame", function() end)
    replace(Pokedex, "drawControlInfo", function() end)
    replace(Bag, "drawArrow", function() return true end)

    local schema, warnings = nil, 0
    local mod = {
      options = { define = function(_, rows) schema = rows end },
      log = { warn = function() warnings = warnings + 1 end },
      hooks = { wrap = function(_, name, callback)
        Runtime.hooks:wrap(name, callback, 0, "static_camera_help_test")
        if name == "core.update" then update = callback
        elseif name == "core.quit_to_launcher" then quit = callback end
      end },
      read = function(_, path)
        if path == "geometry.lua" then return "return {}" end
        if path == "adapter_gen3.lua" then return "return {start=function() end}" end
        local file = assert(io.open(root .. "\\" .. path, "rb"))
        local text = file:read("*a")
        file:close()
        return text
      end,
    }
    assert(loadfile(root .. "\\main.lua"))()(mod)
    T.check(update and quit, "help registers update and quit lifecycle hooks")
    local manifest = { id = "static_camera", name = "Static Camera", enabled = true,
      state = "loaded", version = "0.7.0", category = "qol", profile = "content" }
    local writes, events = 0, {}
    local game = {
      reset = function() return "reset", nil, 3 end,
      save = { options = {} },
      writeOptions = function() writes = writes + 1 end,
      mods = {
        optionSchemas = { static_camera = schema },
        modOptions = { static_camera = {} },
        events = { emit = function(_, name, payload)
          events[#events + 1] = { name = name, payload = payload }
        end },
        status = function() return { available = { manifest }, errors = {} } end,
      },
    }
    local baseReset = game.reset
    local function tick()
      local a, b, c = Runtime.hooks:call("core.update", function() return "tick", nil, 3 end, game, 0)
      T.eq(a, "tick", "update result retained")
      T.eq(b, nil, "update nil result retained")
      T.eq(c, 3, "update result arity retained")
    end
    local function input(...)
      local keys = {}
      for i = 1, select("#", ...) do keys[select(i, ...)] = true end
      return { wasPressed = function(_, key) return keys[key] or false end }
    end
    local function press(...)
      local top = assert(Stack.top(), "input requires a stack layer")
      top.mod.handleInput(input(...))
    end
    local function draw()
      prints, frames = {}, {}
      Stack.top().mod.draw()
      return prints
    end
    local function textAt(y)
      for _, row in ipairs(prints) do if row.y == y then return row.text end end
    end
    local function hasText(text)
      for _, row in ipairs(prints) do if row.text == text then return true end end
      return false
    end
    local function helpOpen()
      return Stack.top() and Stack.top().id == "static_camera_settings_help"
    end
    local function show()
      Manager.show({ game = game })
      local m = Manager._mgr
      m.currentMod = manifest
      m:openOptions(manifest)
      tick()
      return m, Stack.top()
    end
    local m, layer = show()
    local wrapped = m.updateOptions
    for _ = 1, 3 do tick() end
    T.eq(m.updateOptions, wrapped, "repeated updates never stack wrappers")
    T.eq(State.updateOptions, classOptions, "ManagerState class remains untouched")
    T.eq(Manager.draw, originalDraw, "FRLG module draw remains untouched")
    T.check(layer.mod ~= Manager, "affordance belongs only to live stack entry")
    local expected = { mode = true, zoom_style = true, zoom = true, framing = true,
      padding = true, resolution = true, void_fill = true, transition = true, duration = true, reverse = true }
    local byKey = {}
    for _, row in ipairs(schema) do byKey[row.key] = row end
    local stored = game.mods.modOptions.static_camera
    stored.padding = 999
    game.mods.modOptions.other_mod = { zoom = 800 }
    for _, case in ipairs({
      { 800, 200 }, { 1, 5 }, { 125, 125 }, { 127, 125 }, { 128, 130 },
      { "125", 200 }, { false, 200 }, { 0 / 0, 200 }, { math.huge, 200 }, { -math.huge, 200 },
    }) do
      stored.zoom = case[1]
      local before, eventCount = writes, #events
      tick()
      T.eq(stored.zoom, case[2], "saved zoom is normalized by actual manager")
      local changed = case[1] ~= case[2]
      T.eq(writes, before + (changed and 1 or 0), "normalization writes only changed zoom")
      T.eq(#events, eventCount + (changed and 1 or 0), "normalization emits exactly one option event")
      if changed then
        T.eq(game.save.options.modOptions.static_camera.zoom, case[2], "normalization updates saved options")
        T.eq(events[#events].name, "mod.options_changed", "normalization uses standard manager event")
        T.same(events[#events].payload, { mod = "static_camera", key = "zoom", value = case[2] },
          "normalization event is scoped to zoom")
      end
      tick()
      T.eq(writes, before + (changed and 1 or 0), "normalized values are never rewritten each frame")
      T.eq(stored.padding, 999, "normalization leaves other settings untouched")
      T.eq(game.mods.modOptions.other_mod.zoom, 800, "normalization leaves other mods untouched")
    end
    T.eq(warnings, 1, "saved zoom adjustment logs once across all corrections")
    stored.zoom = 800
    Runtime.safeMode = true
    local beforeMigration = writes
    tick()
    T.eq(stored.zoom, 800, "safe mode never normalizes persisted options")
    T.eq(writes, beforeMigration, "safe mode never writes normalization")
    Runtime.safeMode = false
    m.currentMod = { id = "other_mod" }
    tick()
    T.eq(stored.zoom, 800, "another mod options screen does not migrate Static Camera")
    m.currentMod, m.screen = manifest, "detail"
    tick()
    T.eq(stored.zoom, 800, "detail screen does not migrate settings")
    m.screen = "options"
    Stack.push("migration_blocker", {})
    tick()
    T.eq(stored.zoom, 800, "covered options do not migrate settings")
    Stack.pop("migration_blocker")
    for i, row in ipairs(m.optionRows) do if row.id == "zoom" then m.cursor = i end end
    press("left")
    T.eq(stored.zoom, 195, "normalization precedes stock editing of an old zoom value")
    T.eq(m.optionRows[m.cursor].value(), "195", "displayed zoom equals normalized saved value")
    stored.zoom, stored.padding, m.cursor = 200, nil, 1
    for i, option in ipairs(m.optionRows) do
      if expected[option.id] or option.id == "__reset" then
        expected[option.id] = nil
        m.cursor, m.scroll = i, math.max(0, i - 4)
        draw()
        T.check(hasText("Select:HELP"), option.id .. " has scoped affordance")
        local before = writes
        press("select", "right")
        T.check(helpOpen(), option.id .. " Select opens help before a simultaneous setting change")
        local cursor = m.cursor
        press("a", "start")
        m:updateOptions(input("right"))
        T.eq(writes, before, option.id .. " help blocks activation and direct underlying updates")
        T.eq(m.cursor, cursor, option.id .. " help does not move settings cursor")
        draw()
        T.check(hasText("B/Select:BACK"), "help advertises close controls")
        T.check(hasText("LEFT/RIGHT:PAGE"), "help advertises page controls")
        local indicator
        for _, row in ipairs(prints) do if row.x == 184 then indicator = row.text end end
        local count = tonumber(assert(indicator):match("^1/(%d+)$"))
        T.check(count and count > 1, option.id .. " detailed help is paginated")
        local collected = {}
        for page = 1, count do
          draw()
          T.check(hasText(page .. "/" .. count), "page indicator follows navigation")
          for _, rect in ipairs(frames) do
            T.check(rect.x >= 0 and rect.y >= 0 and rect.x + rect.w <= 240
              and rect.y + rect.h <= 160, "help frame border stays inside 240x160")
          end
          for _, row in ipairs(prints) do
            T.check(row.x >= 0 and row.y >= 0 and row.y + 15 <= 160
              and row.x + (row.width or 208) <= 240, "help text allocation stays inside viewport")
            T.check(Font.measure(row.text) <= row.width, "help text is not horizontally clipped")
            if row.y >= 58 and row.y <= 112 then
              T.check(#row.text <= 26, "body uses at most 26 ASCII columns")
              collected[#collected + 1] = row.text
            end
          end
          press("right")
        end
        draw()
        T.check(hasText(count .. "/" .. count), "next at last page stays in bounds")
        if byKey[option.id] then
          T.eq(table.concat(collected, " "), byKey[option.id].help:gsub("%s+", " "),
            option.id .. " every word of supplied detail is reachable")
        end
        press("left")
        draw()
        T.check(hasText((count - 1) .. "/" .. count), "left goes to previous page")
        press("down")
        draw()
        T.check(hasText(count .. "/" .. count), "down also pages forward")
        press("select")
        T.check(not helpOpen(), "Select closes help without leaving options")
        T.eq(m.screen, "options", "closing help retains options screen")
        press("select")
        press("b", "right")
        T.check(not helpOpen(), "B closes before processing simultaneous direction")
        T.eq(writes, before, "all help navigation leaves saved settings untouched")
      end
    end
    T.eq(next(expected), nil, "all ten stable setting keys were exercised")
    m.cursor, m.scroll = 1, 0
    press("right")
    T.check(writes > 0, "stock option editing still works outside help")
    local custom = { id = "unknown", label = "UNKNOWN", step = function() writes = writes + 1 end }
    m.optionRows[#m.optionRows + 1], m.cursor = custom, #m.optionRows + 1
    draw()
    T.check(not hasText("Select:HELP"), "unknown settings never advertise help")
    local before = writes
    press("select", "right")
    T.eq(writes, before + 1, "unknown settings pass through Select combinations")
    T.check(not helpOpen(), "unknown setting does not open help")
    m.cursor = 1
    m.currentMod = { id = "other_mod" }
    draw()
    T.check(not hasText("Select:HELP"), "other mods have no help affordance")
    press("select")
    T.check(not helpOpen(), "other mod Select passes through")
    m.currentMod = manifest
    m.overlay = { kind = "notice", lines = { "BUSY" } }
    press("select")
    T.check(not helpOpen(), "existing overlay excludes help")
    m.overlay = nil
    Manager._prompt = { kind = "qty", value = 1, max = 3 }
    press("select")
    T.check(not helpOpen(), "existing quantity prompt excludes help")
    Manager._prompt = nil
    m.screen = "detail"
    draw()
    T.check(not hasText("Select:HELP"), "detail/global manager never gains a help hint")
    m.screen = "options"
    Stack.push("other_screen", { handleInput = function() end })
    m:updateOptions(input("select"))
    T.check(not helpOpen(), "covered manager cannot open help")
    Stack.pop("other_screen")

    press("select")
    Stack.push("interrupt", {})
    tick()
    T.check(not Stack.has("static_camera_settings_help"), "new modal retires help only")
    T.eq(Stack.top().id, "interrupt", "new modal is not accidentally popped")
    Stack.pop("interrupt")
    press("select")
    m.overlay = { kind = "notice" }
    tick()
    T.check(not helpOpen(), "new stock overlay retires help")
    m.overlay = nil
    press("select")
    Manager.close()
    tick()
    T.eq(m.updateOptions, classOptions, "closed manager restores inherited method")
    T.eq(rawget(m, "updateOptions"), nil, "cleanup restores raw instance shape")
    T.eq(game.reset, baseReset, "closed manager restores reset")
    T.eq(Stack.depth(), 0, "closing manager also removes orphan help")
    local previous = m
    m, layer = show()
    T.check(m ~= previous and m.updateOptions ~= classOptions, "recreated manager attaches once")

    press("select")
    local a, b, c = game:reset()
    T.eq(a, "reset", "reset return retained")
    T.eq(b, nil, "reset nil retained")
    T.eq(c, 3, "reset arity retained")
    T.check(not helpOpen(), "reset closes help immediately")
    T.eq(m.updateOptions, classOptions, "reset removes instance methods")
    tick()
    T.eq(m.updateOptions, classOptions, "reset does not revive the retired manager")
    Manager.close()
    m, layer = show()
    press("select")
    GV.current = "red"
    tick()
    T.check(not helpOpen(), "leaving FRLG closes help")
    T.eq(m.updateOptions, classOptions, "leaving FRLG restores manager")
    GV.current = "firered"
    Manager.close()
    m, layer = show()
    press("select")
    Runtime.hooks:removeOwner("static_camera_help_test")
    local cachedPanel = Stack.top().mod
    cachedPanel.handleInput(input("right"))
    T.check(not helpOpen(), "removed owner is detected by panel without an update hook")
    T.eq(m.updateOptions, classOptions, "removed owner detaches manager")
    T.eq(layer.mod, Manager, "removed owner restores original stack module")
    update(function() end, game, 0)
    T.eq(m.updateOptions, classOptions, "stale callback cannot reattach removed owner")

    Runtime.hooks:wrap("core.update", update, 0, "static_camera_help_test")
    Manager.close()
    m, layer = show()
    press("select")
    local priorOptions, priorReset, priorProxy = m.updateOptions, game.reset, layer.mod
    local foreignOptions = function(self, ...) return priorOptions(self, ...) end
    local foreignReset = function(self, ...) return priorReset(self, ...) end
    local foreignProxy = setmetatable({}, { __index = priorProxy })
    m.updateOptions, game.reset, layer.mod = foreignOptions, foreignReset, foreignProxy
    quit(function() return "quit" end)
    T.check(not helpOpen(), "quit clears active help")
    T.eq(m.updateOptions, foreignOptions, "cleanup preserves later foreign method wrapper")
    T.eq(game.reset, foreignReset, "cleanup preserves later foreign reset wrapper")
    T.eq(layer.mod, foreignProxy, "cleanup preserves later foreign draw wrapper")
    before = writes
    m:updateOptions(input("select", "right"))
    T.eq(writes, before + 1, "retired wrapper underneath another mod is inert passthrough")
    T.check(not helpOpen(), "foreign wrapper cannot revive disposed help")
    game.reset = baseReset
    Manager.close()
    m, layer = show()
    press("select")
    local goodPrint = Window.printPx
    Window.printPx = function() error("injected help draw error") end
    T.raises(function() Stack.top().mod.draw() end, "injected help draw error", "help draw failure propagates")
    Window.printPx = goodPrint
    T.check(not helpOpen(), "help draw error removes its panel")
    T.eq(m.updateOptions, classOptions, "help draw error detaches methods")
    tick()
    T.eq(m.updateOptions, classOptions, "faulted manager is not patched again")
    Manager.close()
    m, layer = show()
    press("select")
    T.raises(function() update(function() error("injected update error") end, game, 0) end,
      "injected update error", "downstream game update error propagates")
    T.check(not helpOpen(), "update error closes help")
    T.eq(m.updateOptions, classOptions, "update error restores manager")
    T.eq(State.updateOptions, classOptions, "class method unchanged after lifecycle tests")
    T.eq(Manager.draw, originalDraw, "module method unchanged after lifecycle tests")
  end, debug.traceback)
  cleanup()
  if not ok then error(err, 0) end
end
