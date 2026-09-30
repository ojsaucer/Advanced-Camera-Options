return function(mod)
  local zoomLimits = { { "OFF", 0 } }
  for percent = 5, 200, 5 do
    zoomLimits[#zoomLimits + 1] = { percent .. "%", percent }
  end
  local rows = {
    { key = "mode", label = "CAMERA MODE", type = "choice", default = "full",
      choices = { { "FULL", "full" }, { "SCROLL", "scroll" }, { "HYBRID", "hybrid" },
        { "BOUNDED", "partial" }, { "NORMAL", "normal" } },
      help = "FULL: fit the entire selected area and keep the camera stationary. "
        .. "Different screen and area shapes may leave backdrop margins. "
        .. "SCROLL (Full-Scroll): zoom in until the area's shorter dimension exactly "
        .. "fills the viewport; that axis then stays stationary like FULL, while the "
        .. "camera follows the player along the other, longer dimension, stopping "
        .. "at its edges. A tie (neither dimension is shorter) keeps both axes "
        .. "stationary like FULL. "
        .. "HYBRID: zoom into FULL and follow the player. Only FULL's edge-touching "
        .. "axis stops at the area edges; a tie constrains both. "
        .. "BOUNDED: follow the player, stopping at the area's edges. "
        .. "NORMAL: use the game's original camera; other camera settings do not apply. "
        .. "FULL, SCROLL, HYBRID and BOUNDED also follow the game's Tilt setting." },
    { key = "connected", label = "CONNECTIONS", type = "choice", default = false,
      choices = { { "OFF", false }, { "ON", true } },
      help = "FULL, HYBRID and BOUNDED. ON displays directly connected maps wherever they appear "
        .. "around the current area's view. The current area's framing and zoom stay "
        .. "unchanged; neighbors show terrain only, without NPC sprites. Gaps "
        .. "still use VOID BACKDROP. In BOUNDED this only fills in scenery the moving "
        .. "camera can already see past the area's edge; it never repositions the camera "
        .. "toward areas the player has not entered. OFF isolates the current area. "
        .. "If extra scenery exceeds available memory it is omitted, not used to reframe the camera." },
    { key = "neighbor_shade", label = "MAP SHADE", type = "choice", default = "off",
      choices = { { "OFF", "off" }, { "UNIFORM", "uniform" }, { "GRADIENT", "gradient" } },
      help = "FULL, HYBRID and BOUNDED. Darkens everything outside the active map's own rectangle "
        .. "to mark its boundary: connected neighboring maps (CONNECTIONS on) and the "
        .. "VOID BACKDROP margin (GAME/EXTRUDE) alike, as one continuous shaded area. "
        .. "OFF leaves them unchanged. UNIFORM darkens them equally; GRADIENT starts "
        .. "clear at the active map's edge and gets darker with distance. The current "
        .. "map, characters and UI are never darkened by this setting." },
    { key = "neighbor_darkness", label = "SHADE STRENGTH %", type = "number",
      default = 60, min = 0, max = 100, step = 5,
      help = "MAP SHADE only. The amount of darkening applied to neighboring maps "
        .. "and VOID BACKDROP margin alike: 0% leaves tiles unchanged and 100% makes "
        .. "them black. UNIFORM applies it everywhere outside the active map. GRADIENT "
        .. "reaches this strength at SHADE DISTANCE. It never changes the brightness of "
        .. "your current area's tiles." },
    { key = "neighbor_distance", label = "SHADE DISTANCE", type = "number",
      default = 8, min = 1, max = 32, step = 1,
      help = "MAP SHADE GRADIENT only. Distance in map tiles from the active "
        .. "area's edge before shading reaches SHADE STRENGTH, measured the same way "
        .. "across neighboring maps and the VOID BACKDROP margin. A smaller value makes "
        .. "a sharper boundary; a larger value creates a gentler fade. UNIFORM and OFF "
        .. "ignore this distance." },
    { key = "hybrid_zoom", label = "HYBRID ZOOM %", type = "number",
      default = 100, min = 100, max = 200, step = 5,
      help = "HYBRID only: 100 to 200%, in steps of 5. Magnifies FULL's fitted view, "
        .. "including its Tilt perspective. 100% keeps FULL's scale; 200% doubles it. "
        .. "Follow the player on both axes, stopping only on FULL's edge-touching axis "
        .. "(both if tied). At 100% that axis stays centered. The other axis follows "
        .. "freely and can reveal connected scenery or VOID BACKDROP. "
        .. "BOUNDED BASIS, BOUNDED ZOOM and MAX ZOOM do not affect HYBRID." },
    { key = "zoom_style", label = "BOUNDED: BASIS", type = "choice", default = "consistent",
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
        .. "BOUNDED BASIS. The limit overrides both requested zoom and small-room zoom-in. "
        .. "Small rooms use the selected backdrop on axes that cannot fill the view. "
        .. "The camera still follows within bounds wherever there is room. FULL, SCROLL and HYBRID are unchanged." },
    { key = "framing", label = "AREA FRAMING", type = "choice", default = "scene",
      choices = { { "SCENE", "scene" }, { "TERRAIN", "reachable" } },
      help = "SCENE keeps the complete authored map rectangle, including decorative scenery. "
        .. "TERRAIN crops to a rectangle around terrain reachable from your entry tile. "
        .. "It includes water and ignores badges, HM access and temporary NPC blockers. "
        .. "Works in FULL, SCROLL, HYBRID or BOUNDED; irregular holes inside the rectangle can remain." },
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
    { key = "screen_filter", label = "SCREEN FILTER", type = "choice", default = "crisp",
      choices = { { "CRISP", "crisp" }, { "SMOOTH", "smooth" } },
      help = "SCREEN resolution only. CRISP keeps hard pixel edges. SMOOTH filters "
        .. "zoomed-out terrain detail to reduce shimmering and lost thin patterns, "
        .. "including Tilt ground and decorative backdrop. Normal-size and enlarged "
        .. "pixels stay crisp. Upright Tilt actors keep the engine's sprite sampling. "
        .. "SMOOTH uses extra texture memory within the same camera limit. "
        .. "RETRO and the normal game camera are unchanged." },
    { key = "void_fill", label = "VOID BACKDROP", type = "choice", default = "black",
      choices = { { "BLACK", "black" }, { "GAME", "game" }, { "EXTRUDE", "extrude" } },
      help = "BLACK keeps empty margins black. GAME repeats the pattern selected in the "
        .. "game's Extras > Void Fill option behind the framed area, including Tilt margins. "
        .. "This is a decorative backdrop, not loaded neighboring terrain. Camera bounds "
        .. "and actual black map tiles stay unchanged. TREES/WATER availability follows "
        .. "the game: incompatible tilesets use the map's own border instead. "
        .. "EXTRUDE completes recognized trees, rocks, shorelines, water and other "
        .. "boundary scenery as whole patterns extending outward; buildings extend as "
        .. "trees and cliffs as mountaintop or continued wall terrain. Viridian Forest "
        .. "uses its own tree pattern. Only unrecognized scenery repeats its single "
        .. "edge tile outward instead. "
        .. "Indoors and underground, EXTRUDE automatically uses BLACK instead. "
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
