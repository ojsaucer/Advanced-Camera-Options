return function(mod)
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
        .. "Either basis zooms in more if required to keep the view inside a small area." },
    { key = "zoom", label = "BOUNDED ZOOM %", type = "number",
      default = 200, min = 5, max = 200, step = 5,
      help = "BOUNDED mode only: 5 to 200%, in steps of 5. Higher means closer; lower shows "
        .. "more area. With NORMAL basis, 100% is normal engine zoom and 50% is half that scale. "
        .. "The area boundary sets a minimum effective zoom, so lowering this value may stop "
        .. "making a difference on small maps. FULL mode fits the whole area instead." },
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
        { "H-SCROLL", "horizontal" }, { "V-SCROLL", "vertical" } },
      help = "How to switch camera views at an area change: NONE switches immediately; "
        .. "FADE passes through black; H-SCROLL moves horizontally; V-SCROLL moves vertically. "
        .. "Doors and warps that already have an engine transition keep that single effect "
        .. "instead of playing a second camera transition. NORMAL camera mode is unaffected." },
    { key = "duration", label = "TRANSITION MS", type = "number",
      default = 350, min = 50, max = 2000, step = 50,
      help = "Camera transition duration in milliseconds: 1000 ms equals one second. "
        .. "Higher is slower. FADE includes both fading out and fading in within this time. "
        .. "Applies to FADE and both scroll effects, not NONE. The game's own door and "
        .. "script transitions keep their original timing." },
    { key = "reverse", label = "SCROLL DIRECTION", type = "choice", default = false,
      choices = { { "NORMAL", false }, { "REVERSE", true } },
      help = "Scroll effects only. NORMAL brings the new view in from the right for "
        .. "H-SCROLL, or from below for V-SCROLL. REVERSE uses the opposite side. "
        .. "Direction is chosen here, not from the player's movement or door orientation. "
        .. "This setting does not affect FADE or NONE." },
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
  adapter.start(mod, geometry, {
    geometry = module("tilt_geometry.lua"),
    render = module("tilt_render.lua"),
  }, module("void_backdrop.lua"), compatibility)
  module("settings_help.lua").start(mod, rows, compatibility)
end
