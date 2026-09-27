local Help = {}
local function pack(...) return { n = select("#", ...), ... } end

function Help.start(mod, rows, compatibility)
  if not compatibility.check("help") then return end
  local Runtime = require("src.mods.Runtime")
  local GameVersion = require("src.core.GameVersion")
  local Manager = require("src.ui.game3.mod_manager")
  local Stack = require("src.ui.game3.stack")
  local Window = require("src.ui.game3.window")
  local Font = require("src.ui.game3.frlg_font")
  local lg = love.graphics
  local details, zoomRow, zoomWarned = {}
  for _, row in ipairs(rows) do
    if row.key == "zoom" and row.type == "number" then zoomRow = row end
    if type(row.key) == "string" and type(row.help) == "string" and row.help ~= "" then
      details[row.key] = { label = row.label or row.key, text = row.help }
    end
  end
  details.__reset = { label = "RESET DEFAULTS",
    text = "Press A on RESET DEFAULTS to restore every Static Camera setting "
      .. "to its default immediately. This does not change other mods. "
      .. "Opening this help does not reset anything." }

  local attachment, update
  local failed = setmetatable({}, { __mode = "k" })
  local function alive()
    for _, link in ipairs((Runtime.hooks.chains or {})["core.update"] or {}) do
      if link.callback == update then return true end
    end
    return false
  end
  local function supported()
    local version = GameVersion.get()
    return version == "firered" or version == "leafgreen"
  end
  local function managerLayer()
    for _, layer in ipairs(Stack._layers) do
      if layer.id == "mod_manager" then return layer end
    end
  end
  local function pagesFor(text)
    local lines, line = {}, ""
    local function fits(s) return #s <= 26 and Font.measure(s) <= 208 end
    local function flush()
      if line ~= "" then lines[#lines + 1], line = line, "" end
    end
    for word in text:gmatch("%S+") do
      if line ~= "" and fits(line .. " " .. word) then
        line = line .. " " .. word
      else
        flush()
        -- Split unusually long words rather than silently clipping help.
        for i = 1, #word do
          local char = word:sub(i, i)
          if not fits(line .. char) then flush() end
          line = line .. char
        end
      end
    end
    flush()
    local pages = { {} }
    for _, textLine in ipairs(lines) do
      if #pages[#pages] == 4 then pages[#pages + 1] = {} end
      local page = pages[#pages]
      page[#page + 1] = textLine
    end
    return pages
  end

  local function bind(game, m, layer)
    local oldOptions, rawOptions = m.updateOptions, rawget(m, "updateOptions")
    local oldReset, rawReset = game.reset, rawget(game, "reset")
    local originalModule = layer.mod
    local wrappedOptions, wrappedReset, proxy, panel, detached
    local function close()
      if not panel then return end
      -- Remove only our actual layer, never somebody else's same-id layer.
      for i = #Stack._layers, 1, -1 do
        if Stack._layers[i].mod == panel then table.remove(Stack._layers, i) end
      end
      panel = nil
    end
    local function detach()
      if detached then return end
      detached = true
      failed[m] = true
      close()
      if m.updateOptions == wrappedOptions then m.updateOptions = rawOptions end
      if game.reset == wrappedReset then game.reset = rawReset end
      if layer.mod == proxy then layer.mod = originalModule end
    end
    local function valid()
      if detached then return false end
      if not alive() or not supported() or not Manager.open or Manager._mgr ~= m
        or Manager._game ~= game or managerLayer() ~= layer then
        detach()
        return false
      end
      return true
    end
    local function scoped()
      return m.screen == "options" and m.currentMod and m.currentMod.id == "static_camera"
        and not m.overlay and not Manager._prompt
    end
    local function normalizeZoom()
      if Runtime.safeMode or not zoomRow or not scoped() or Stack.top() ~= layer then return end
      local value = m:optionValue("static_camera", zoomRow)
      local number = value
      if type(number) ~= "number" or number ~= number or number == math.huge or number == -math.huge then
        number = zoomRow.default
      end
      local lo, hi, step = zoomRow.min, zoomRow.max, zoomRow.step
      number = math.max(lo, math.min(hi, number))
      number = math.max(lo, math.min(hi, lo + math.floor((number - lo) / step + 0.5) * step))
      if value ~= number and m:setOption("static_camera", "zoom", number) ~= false and not zoomWarned then
        zoomWarned = true
        mod.log:warn("Adjusted saved Static Camera zoom to %s%% to match the supported range and step.",
          tostring(number))
      end
    end
    local function selected()
      local row = (m.optionRows or {})[m.cursor]
      return row and details[row.id]
    end
    local function guarded(fn, ...)
      local r = pack(pcall(fn, ...))
      if not r[1] then
        failed[m] = true
        detach()
        error(r[2], 0)
      end
      return unpack(r, 2, r.n)
    end
    local function printLine(text, x, y, width)
      Window.printPx(text, x, y, { colors = Font.COLOR.NORMAL, maxWidth = width or 208 })
    end
    local function open(detail)
      local pages, page = pagesFor(detail.text), 1
      local owned = {}
      panel = owned
      local function usable()
        if not valid() then return false end
        if not scoped() or not Stack.top() or Stack.top().mod ~= owned then
          close()
          return false
        end
        return true
      end
      owned.handleInput = function(input)
        return guarded(function()
          if not usable() then return end
          if input:wasPressed("b") or input:wasPressed("select") then close()
          elseif input:wasPressed("left") or input:wasPressed("up") then
            page = math.max(1, page - 1)
          elseif input:wasPressed("right") or input:wasPressed("down") then
            page = math.min(#pages, page + 1)
          end
        end)
      end
      owned.update = function() return guarded(usable) end
      owned.draw = function()
        return guarded(function()
          if not usable() then return end
          lg.setColor(0, 0, 0, 1)
          lg.rectangle("fill", 0, 0, 240, 160)
          lg.setColor(1, 1, 1, 1)
          printLine("B/Select:BACK", 16, 0)
          Window.fixedStdFrame(Window.template(2, 3, 26, 2))
          Window.userFrame(Window.template(2, 7, 26, 12), 0)
          printLine(detail.label:sub(1, 18), 16, 25, 160)
          printLine(page .. "/" .. #pages, 184, 25, 40)
          for i, text in ipairs(pages[page]) do printLine(text, 16, 58 + (i - 1) * 18) end
          printLine("LEFT/RIGHT:PAGE", 16, 136)
        end)
      end
      Stack.push("static_camera_settings_help", owned, { fullscreen = true })
    end
    wrappedOptions = function(self, input, ...)
      if not valid() then return oldOptions(self, input, ...) end
      if panel then return end
      guarded(normalizeZoom)
      if scoped() and Stack.top() == layer and selected() and input:wasPressed("select") then
        return guarded(open, selected())
      end
      return guarded(oldOptions, self, input, ...)
    end
    proxy = setmetatable({
      draw = function(...)
        if not valid() then return originalModule.draw(...) end
        local r = pack(guarded(originalModule.draw, ...))
        if scoped() and Stack.top() == layer and selected() then
          guarded(printLine, "Select:HELP", 32, 119, 176)
        end
        return unpack(r, 1, r.n)
      end,
    }, { __index = originalModule })
    wrappedReset = function(self, ...)
      detach()
      return oldReset(self, ...)
    end
    m.updateOptions, layer.mod, game.reset = wrappedOptions, proxy, wrappedReset
    return { game = game, manager = m, layer = layer, dispose = detach,
      valid = valid, refresh = function()
        if panel and (not scoped() or not Stack.top() or Stack.top().mod ~= panel) then close() end
        guarded(normalizeZoom)
      end }
  end
  local function dispose()
    if attachment then attachment.dispose(); attachment = nil end
  end
  update = function(nextUpdate, game, dt)
    local r = pack(pcall(nextUpdate, game, dt))
    if not r[1] then dispose(); error(r[2], 0) end
    if not compatibility.allowed() or not alive() or not supported() or not game then
      dispose()
    else
      local m, layer = Manager._mgr, managerLayer()
      if attachment and (attachment.game ~= game or attachment.manager ~= m
        or attachment.layer ~= layer or not attachment.valid()) then dispose() end
      if Manager.open and Manager._game == game and m and layer and not failed[m] then
        if not attachment then
          if type(m.updateOptions) == "function" and type(game.reset) == "function" then
            attachment = bind(game, m, layer)
          else
            compatibility.warn("help-lifecycle", "Static Camera help unavailable: unsupported settings lifecycle.")
            failed[m] = true
          end
        end
        if attachment then attachment.refresh() end
      else
        dispose()
      end
    end
    return unpack(r, 2, r.n)
  end
  mod.hooks:wrap("core.update", update)
  mod.hooks:wrap("core.quit_to_launcher", function(nextQuit, ...)
    dispose()
    return nextQuit(...)
  end)
end

return Help
