local C = {}

local tested = { ["0.3.19"] = true, ["0.3.22"] = true, ["0.3.33"] = true }
local groups = {
  camera = {
    { "src.mods.Runtime", hooks = "table" },
    { "src.core.GameVersion", "get" },
    { "src.core.game3.field_view", "draw", "flashSpansFor" },
    { "src.core.game3.player" },
    { "src.core.game3.runtime", "isActive", "getSession" },
    { "src.core.game3.map", "worldMidAt", "refreshWorld" },
    { "src.render.Tilt", "active" },
    { "src.render.Renderer" },
    { "src.core.game3.warp", "isBusy" },
    { "src.ui.game3.fade", "isActive" },
    { "src.ui.game3.shop_menu", "isShopCamera" },
    { "src.ui.game3.seagallop", "isActive" },
    { "src.core.game3.camera_object", "isActive" },
    { "src.core.game3.battle_transition", "isActive" },
    { "src.core.game3.bg", "hasVisible" },
    { "src.core.game3.oam" },
  },
  screen = {
    { "src.render.Renderer", "frameRects", "setWorldOverride", "fitScale" },
    { "src.render.Zoom", "scale" },
  },
  tilt = {
    { "src.render.Tilt", "groundPoint", angle = "number", FOCAL = "number" },
    { "src.render.Renderer", "tiltShader", "tiltMesh" },
    { "src.core.game3.ow_sprites" },
    { "src.core.game3.objects" },
  },
  terrain = {
    { "src.core.game3.collision", "ledgeLanding", "inBounds", "isWalkable", "isWater",
      "directionallyImpassable", "elevationAt", "elevationMismatchOn" },
  },
  connections = {
    { "src.core.game3.connections", "each", "sizeOf", "cardinal" },
    { "src.core.game3.map", "ensureMidLayout" },
  },
  backdrop = {
    { "src.core.game3.void_fill", "normalize", "primaryFor", "fillAt", "borderFor" },
    { "src.core.game3.tileset_native", "get", "hasMid", "slotFor", "quad", "overQuad" },
  },
  shade = {
    { "src.core.game3.field_weather", "getWeather", "draw" },
    { "src.core.game3.weather", SHADE = "number" },
  },
  help = {
    { "src.mods.Runtime", hooks = "table" },
    { "src.core.GameVersion", "get" },
    { "src.ui.game3.mod_manager", "draw" },
    { "src.ui.game3.stack", "top", "push", _layers = "table" },
    { "src.ui.game3.window", "printPx", "template", "fixedStdFrame", "userFrame" },
    { "src.ui.game3.frlg_font", "measure", COLOR = "table" },
  },
}

function C.new(mod)
  local self = { modules = {} }
  local warnings = {}
  function self.warn(key, message)
    if not warnings[key] then
      warnings[key] = true
      mod.log:warn("%s", message)
    end
  end
  local function load(name)
    local ok, value = pcall(require, name)
    if not ok then return nil, name .. ": " .. tostring(value) end
    if type(value) ~= "table" then return nil, name .. " is not a module table" end
    self.modules[name] = value
    return value
  end
  local version, versionError = load("src.core.Version")
  self.engine = version and version.engine
  function self.supported()
    local patch = type(self.engine) == "string" and self.engine:match("^0%.3%.(%d+)$")
    if not version or version.modApi ~= 2 or not patch or tonumber(patch) < 19 then
      self.warn("engine", "Static Camera inactive: requires a stable 0.3.19+ engine in the "
        .. "0.3.x family and mod API 2. Detected " .. tostring(self.engine)
        .. (versionError and (": " .. versionError) or "") .. ". Normal camera retained.")
      return false
    end
    return true
  end
  function self.allowed()
    if not self.supported() then return false end
    if tested[self.engine] then return true end
    if mod.options:get("experimental") ~= true then
      self.warn("unverified", "Static Camera inactive on untested engine " .. self.engine
        .. ". Enable UNTESTED ENGINE in mod options to try it, or leave OFF for the normal camera.")
      return false
    end
    self.warn("experimental", "Experimental Static Camera on untested engine " .. self.engine
      .. ": capability checks cannot verify internal rendering behavior. Turn UNTESTED ENGINE off if problems occur.")
    return true
  end
  function self.check(group)
    if not self.supported() then return false end
    for _, spec in ipairs(assert(groups[group], "Unknown compatibility group")) do
      local object, err = load(spec[1])
      if object then
        for i = 2, #spec do
          if type(object[spec[i]]) ~= "function" then
            err = spec[1] .. "." .. spec[i] .. " is not a function"
            break
          end
        end
        for key, expected in pairs(spec) do
          if type(key) == "string" and type(object[key]) ~= expected then
            err = spec[1] .. "." .. key .. " is not " .. expected
            break
          end
        end
      end
      if err then
        self.warn(group, "Static Camera " .. group .. " unavailable: " .. err
          .. ". This feature will not be installed; restart the game after updating the mod/engine.")
        return false
      end
    end
    if group == "camera" or group == "help" then
      local runtime = self.modules["src.mods.Runtime"]
      if type(runtime.hooks.chains) ~= "table" then
        self.warn("hooks", "Static Camera inactive: unsupported hook registry. Normal behavior retained.")
        return false
      end
    end
    if group == "camera" then
      for _, key in ipairs({ "getStackDepth", "getCanvas", "setCanvas", "push", "pop",
        "newCanvas", "newQuad", "draw", "origin", "setShader", "setScissor", "setBlendMode",
        "clear", "setColor", "scale" }) do
        if type(love.graphics[key]) ~= "function" then
          self.warn("graphics", "Static Camera inactive: missing love.graphics." .. key .. ". Normal camera retained.")
          return false
        end
      end
      if group == "tilt" and type(love.graphics.translate) ~= "function" then
        self.warn("billboard", "Static Camera Tilt unavailable: missing billboard translation capability.")
        return false
      end
    end
    return true
  end
  return self
end

return C
