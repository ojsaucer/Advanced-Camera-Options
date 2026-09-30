# Changelog

What's new for players. For implementation and testing details, see the
[technical reference](docs/TECHNICAL.md).

## 0.16.1

- Fixed a performance regression affecting every camera mode other than
  NORMAL: the void backdrop (GAME and EXTRUDE) was fully recomputing its
  entire tile-by-tile plan every single frame, even when the map, tileset
  and settings hadn't changed since the previous frame. It's now cached and
  instantly reused across unchanged frames, recomputing only when the map,
  tileset or relevant settings actually change. Benchmarked at roughly a
  700-900x reduction in per-frame cost for typical outdoor maps using
  EXTRUDE, and up to ~1 millisecond saved per frame on a large, mostly-open
  map.

## 0.16.0

- Added support for **Pokemon Emerald**. All camera modes, transitions and
  settings work the same as on FireRed/LeafGreen.
- Removed the EXTRUDE DEPTH setting. Unrecognized scenery now always repeats
  a single boundary tile outward, which looks more polished than the deeper
  multi-row repeat the old setting allowed.
- Fixed EXTRUDE repeating walkable ground (plain grass, tall grass, paths)
  into the backdrop, which looked like more walkable area existed past the
  map's actual edge. It now substitutes the nearest non-walkable boundary
  tile (a fence, tree, wall or water tile) found along that same edge instead.
- EXTRUDE now also completes Emerald's own General-tileset trees as whole
  patterns (verified against Littleroot Town, Oldale Town, Route 101 and
  Petalburg Woods), using Emerald's own tileset artwork independently of
  FireRed/LeafGreen's. Other Emerald scenery (rocks, water, fences, walls)
  still uses plain edge-tile repetition for now.
- Recognized additional fence and guardrail pieces (including Route 11's
  bridge railing) in FireRed/LeafGreen's EXTRUDE.
- Verified against Gen1Recomp 0.3.33, the first engine build with Emerald
  support; it's now a tested engine version alongside 0.3.19 and 0.3.22.

## 0.15.0

- Added SCROLL (Full-Scroll) mode: zoom in until the area's shorter dimension
  exactly fills the viewport (staying stationary like Full), while the camera
  follows the player along the other, longer dimension, stopping at its edges.
  A tie keeps both axes stationary like Full. This corrects an initial version
  of this mode that locked the wrong axis, so the camera never actually scrolled.
- CONNECTIONS and MAP SHADE now also work in Bounded mode, filling in scenery
  or darkening only what the moving camera can already see past the area's
  edge; they never reposition the camera toward areas you haven't entered.
- Fixed EXTRUDE's concave (inner) map-boundary corners so they blend the two
  meeting edges instead of repeating a single corner tile, fixing several
  tree/rock-wall and building/path corner seams. This fixes a bug where the
  blend silently discarded a valid match whenever only one side of a corner
  was recognized scenery (the common case of a wall or fence corner meeting
  ordinary terrain), which had made most of these corner fixes ineffective.
- Added a recognized fence family so fences repeat as themselves instead of
  being overwritten by neighboring tree/cliff rules.
- Recognized two more 3x2 bush-border tree families (in addition to Viridian
  Forest's), completing more maps' partial borders instead of repeating cut
  fragments.

## 0.14.0

- Added Hybrid mode: zoom into Full's view from 100-200%, follow the player, and
  constrain only Full's edge-touching axis. Connections and Map Shade are shared
  by Full and Hybrid.
- Added optional SCREEN FILTER: keep the default crisp pixels or choose Smooth
  to reduce zoomed-out aliasing in terrain and backgrounds.
- Extended straight rock walls across map edges and continued wall corners with
  appropriately oriented wall pieces, rather than replacing every wall with
  mountaintop terrain.
- Fixed more mixed rock/water extensions around Seafoam and completed paired
  tree canopies along water boundaries.

## 0.13.1

- Fixed incomplete tree repetition around Viridian Forest by using its own
  three-tile-wide tree pattern, and recognized more outdoor tree-edge pieces.
- Removed more repeated water-rock variants from ocean extensions.
- Replaced recognized building and gatehouse extensions with trees, and cliff
  extensions with solid mountaintop terrain. The real map remains unchanged.

## 0.13.0

- Made EXTRUDE content-aware for recognized General-tileset scenery: complete
  tree patterns, ocean water instead of repeated water rocks, and a short
  shoreline completion before open water.
- Unrecognized scenery still uses the existing edge strips and selected depth.
  Indoor black backgrounds, map shading and camera framing are unchanged.

## 0.12.1

- EXTRUDE now uses a black backdrop indoors and underground instead of repeating
  walls, decorations and empty tiles.
- Fixed thin gaps where extruded backgrounds meet the map at fractional zoom.
- Map Shade now also darkens GAME and EXTRUDE backgrounds, with a continuous
  gradient around the current map, even with connected scenery turned off.
- Connected scenery no longer displays or loads neighboring NPC sprites.

## 0.12.0

- Added EXTRUDE backgrounds that repeat the map's individual edge tiles, with
  adjustable strip depth from 1 to 16 tiles.
- Added optional uniform or gradient darkening for connected-map terrain,
  with adjustable strength and fade distance. Your current map stays unchanged.
- Grouped Full-specific options together, followed by Bounded-specific options
  and shared camera settings.
- Prevented optional connected scenery from changing camera resolution or
  falling back to the vanilla camera when its larger image cannot be allocated.

## 0.11.0

- Added an optional maximum zoom for Bounded mode, keeping small interiors from
  becoming too enlarged. Extra space uses your chosen backdrop.
- Added optional connected-map scenery in Full mode without changing its framing.
- Replaced horizontal/vertical scrolling and reverse direction with one
  direction-aware Slide transition.
- Kept camera framing steady during ordinary battle-entry animations. Screen
  rendering briefly uses native pixel resolution to preserve the game's effects.
- Added an in-game settings preview: press Start to preview, then B to return
  without moving the player or losing your menu position.

## 0.10.1

- Added the GitHub update information needed by the Gen1Recomp launcher.
- Reworked the project page with clearer features, setup instructions and known issues.
- Added a disclosure about Astra's role in developing the mod.
- No camera or gameplay changes from 0.10.0.

## 0.10.0

- Tilt sprites now get smaller in the distance and larger closer to the camera.
- Whole-area framing makes room for the differently sized sprites.
- Documented the existing issue where the player can leave the visible screen
  at the bottom corners in Bounded mode with Tilt. The strict bounds remain unchanged.
- Included the compatibility and shaded-background fixes from the local 0.9.x builds.

## 0.9.1

- Fixed bright Void Fill backgrounds in areas with the game's forest-shade effect.
- Background shading now follows weather changes and area transitions without
  darkening the map twice or changing dialogue colors.

## 0.9.0

- Added tested support for Gen1Recomp 0.3.22 alongside 0.3.19.
- Added **Untested Engine** so players can opt into trying newer stable 0.3.x builds.
- Missing optional features now fall back individually instead of disabling
  the entire camera where possible.
- Improved cleanup when the camera encounters a rendering problem.

## 0.8.0

- Fixed Void Fill appearing flat around tilted maps. It now follows the map's perspective.
- Prevented inverted terrain above the horizon in small rooms.
- Added downloadable GitHub builds and checksums.

## 0.7.0

- Added **Void Backdrop: GAME**, which uses the game's Void Fill choice around the map.
- Kept black margins as the default. Actual black tiles inside maps are unchanged.

## 0.6.0

- Added Tilt support to Full and Bounded camera modes.
- Fixed lines and color artifacts between tiles while moving at zoomed-out settings.
- Improved framing in small rooms and fallback behavior on devices with less graphics memory.

## 0.5.0

- Added detailed help for each setting: highlight it and press **Select**.
- Made option names clearer and grouped related settings.
- Expanded Bounded zoom to **5-200% in 5% steps**.
- Fixed duplicate transitions when entering or leaving doors.

## 0.4.0

- Added consistent zoom across differently sized areas.
- Kept area-relative zoom as an alternative.
- Small areas still enforce a minimum zoom to avoid showing outside the map.

## 0.3.0

- Added **Screen Resolution** for clearer zoomed-out views.
- Kept **Retro** rendering for the original pixelated look.
- Menus and dialogue retain their normal size in either mode.

## 0.2.0

- First working version for the supported upstream engine.
- Added Full, Bounded and Normal cameras, area cropping, padding and transitions.

## 0.1.0 - obsolete prototype

This version depended on a development fork and does not work with the supported
upstream game. Do not install it.
