return function(mod)
  local zoomLimits = { { "OFF", 0 } }
  for percent = 5, 200, 5 do
    zoomLimits[#zoomLimits + 1] = { percent .. "%", percent }
  end
  local rows = {
    { key = "mode", label = "CAMERA MODE", type = "choice", default = "full",
      choices = { { "FULL", "full" }, { "BOUNDED", "partial" }, { "NORMAL", "normal" } },
      help = "FULL: fit the entire selected area and keep the camera stationary. "
        .. "Different screen and area shapes may leave backdrop margins. "
        .. "BOUNDED: follow the player, stopping at the area's edges. "
        .. "NORMAL: use the game's original camera; other camera settings do not apply. "
        .. "FULL and BOUNDED also follow the game's Tilt setting." },
    { key = "zoom_style", label = "ZOOM BASIS", type = "choice", default = "consistent",
      choices = { { "NORMAL", "consistent" }, { "AREA FIT", "relative" } },
      help = "BOUNDED mode only. NORMAL uses consistent zoom: 100% is the normal engine "
        .. "camera scale, so characters keep the same size across maps. "
        .. "AREA FIT multiplies the whole-area fit instead; larger maps show smaller characters. "
        .. "Either basis zooms in more for small areas unless MAX ZOOM limits it." },
    { key = "zoom", label = "BOUNDED ZOOM %", type = "number",
      default = 200, min = 5, max = 200, step = 5,
      help = "BOUNDED mode only: 5 to 200%, in steps of 5. Higher means closer; lower shows "
        .. "more area. With NORMAL basis, 100% is normal engine zoom and 50% is half that scale. "
        .. "Small maps may force a closer view. Use MAX ZOOM to prevent that, allowing "
        .. "backdrop margins instead. FULL mode fits the whole area instead." },
    { key = "max_zoom", label = "MAX ZOOM", type = "choice", default = 0,
      choices = zoomLimits,
      help = "BOUNDED mode only. OFF keeps strict map-only camera bounds. Choose 5 to 200% "
        .. "to set an absolute zoom ceiling: 100% is normal engine scale, regardless of "
        .. "ZOOM BASIS. The limit overrides both requested zoom and small-room zoom-in. "
        .. "Small rooms use the BLACK or GAME backdrop on axes that cannot fill the view. "
        .. "The camera still follows within bounds wherever there is room. FULL is unchanged." },
    { key = "framing", label = "AREA FRAMING", type = "choice", default = "scene",
      choices = { { "SCENE", "scene" }, { "TERRAIN", "reachable" } },
      help = "SCENE keeps the complete authored map rectangle, including decorative scenery. "
        .. "TERRAIN crops to a rectangle around terrain reachable from your entry tile. "
        .. "It includes water and ignores badges, HM access and temporary NPC blockers. "
        .. "Works in FULL or BOUNDED mode; irregular holes inside the rectangle can remain." },
    { key = "padding", label = "CROP PADDING", type = "number",
      default = 1, min = 0, max = 4, step = 1,
      help = "TERRAIN framing only. Add 0 to 4 map tiles around the terrain crop for walls "
        .. "and scenery. One tile is the default. Padding never extends beyond the current "
        .. "map. Changing padding rebuilds the crop; it has no effect with SCENE framing." },
    { key = "connected", label = "CONNECTED MAPS", type = "choice", default = false,
      choices = { { "OFF", false }, { "ON", true } },
      help = "FULL mode only. ON displays directly connected maps wherever they appear "
        .. "around the current area's view. The current area's framing and zoom stay "
        .. "unchanged; neighbors are scenery, not extra areas to fit on screen. Gaps "
        .. "still use VOID BACKDROP. OFF isolates the current area. BOUNDED is unchanged. "
        .. "Loading neighboring scenery can use more memory." },
    { key = "resolution", label = "WORLD RESOLUTION", type = "choice", default = "retro",
      choices = { { "RETRO", "retro" }, { "SCREEN", "screen" } },
      help = "RETRO keeps the chunky low-resolution look and uses less GPU memory. "
        .. "SCREEN draws the world at the game viewport's physical resolution, preserving "
        .. "more zoomed-out detail. Menus and dialogue keep their normal size. "
        .. "SCREEN uses more GPU memory and falls back to RETRO if unavailable." },
    { key = "void_fill", label = "VOID BACKDROP", type = "choice", default = "black",
      choices = { { "BLACK", "black" }, { "GAME", "game" } },
      help = "BLACK keeps empty margins black. GAME repeats the pattern selected in the "
        .. "game's Extras > Void Fill option behind the framed area, including Tilt margins. "
        .. "This is a decorative backdrop, not loaded neighboring terrain. Camera bounds "
        .. "and actual black map tiles stay unchanged. TREES/WATER availability follows "
        .. "the game: incompatible tilesets use the map's own border instead. "
        .. "With Tilt, the pattern follows the same ground perspective. Any space above "
        .. "the horizon stays black. NORMAL uses the game's own rendering." },
    { key = "transition", label = "AREA TRANSITION", type = "choice", default = "fade",
      choices = { { "NONE", "none" }, { "FADE", "fade" },
        { "SLIDE", "slide" } },
      help = "How to switch camera views at an area change: NONE switches immediately; "
        .. "FADE passes through black; SLIDE moves toward the connected area you enter. "
        .. "Unconnected changes without a reliable direction switch immediately. "
        .. "Doors and warps that already have an engine transition keep that single effect "
        .. "instead of playing a second camera transition. NORMAL camera mode is unaffected." },
    { key = "duration", label = "TRANSITION MS", type = "number",
      default = 350, min = 50, max = 2000, step = 50,
      help = "Camera transition duration in milliseconds: 1000 ms equals one second. "
        .. "Higher is slower. FADE includes both fading out and fading in within this time. "
        .. "Applies to FADE and SLIDE, not NONE. The game's own door and "
        .. "script transitions keep their original timing." },
    { key = "experimental", label = "UNTESTED ENGINE", type = "choice", default = false,
      choices = { { "OFF", false }, { "TRY", true } },
      help = "OFF keeps the normal camera on untested engine versions. TRY opts into "
        .. "experimental camera and help adapters on stable 0.3.x engines newer than 0.3.19. "
        .. "Only 0.3.19 and 0.3.22 have passed the regression suite. Capability checks cannot "
        .. "prove unchanged rendering behavior. Turn OFF if problems occur. Tested versions "
        .. "ignore this switch; use CAMERA MODE > NORMAL to disable their camera. "
        .. "Changing this switch applies on the next update; missing features require a restart after repair." },
  }
  mod.options:define(rows)
  local function module(path)
    local text, err = mod:read(path)
    assert(text, err)
    return assert(loadstring(text, "@static_camera/" .. path))()
  end
  local geometry = module("geometry.lua")
  local compatibility = module("compatibility.lua").new(mod)
  local adapter = module("adapter_gen3.lua")
  local preview = adapter.start(mod, geometry, {
    geometry = module("tilt_geometry.lua"),
    render = module("tilt_render.lua"),
  }, module("void_backdrop.lua"), compatibility)
  module("settings_help.lua").start(mod, rows, compatibility, preview)
end
