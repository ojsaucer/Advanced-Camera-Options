# Advanced Camera Options

Static Camera provides a stationary whole-scene view or a closer bounded-follow
view, with selectable full-scene or reachable-terrain framing.

The in-game mod name and saved-settings ID remain **Static Camera** and
`static_camera`, so upgrades preserve existing options.

## Version 0.8.0: perspective-correct Void Fill

Targets **FireRed and LeafGreen on Gen1Recomp 0.3.19, mod API 2**.
The mod uses the explicitly authorized `engine_internals` permission. It does
not require the nonexistent upstream `camera.field` hook and does not edit
engine files, player coordinates, collision, saves, or another mod.

This is a version-sensitive renderer adapter, not a stable public API. The
manifest and adapter reject unknown engine versions until their renderer has
been audited. Gen 1/2 are planned, not implemented. Ruby/Sapphire/Emerald are
not supported.

**Replace the old 0.1.0 prototype; do not use its ZIP.** The new ordinary ZIP
is a candidate for in-game testing, not a Python-modkit-certified `.modpkg`.

## Install

1. Close all running game instances.
2. Download the [v0.8.0 testing ZIP](https://github.com/ojsaucer/Advanced-Camera-Options/releases/download/v0.8.0/static_camera-0.8.0.zip)
   and extract it into the game's
   `mods\static_camera` directory, replacing the previous version's files.
   `manifest.json` must be directly inside `static_camera`, not a nested folder.
3. Enable **Static Camera** for FireRed or LeafGreen. The mod declares
   `engine_internals`; allow that permission if the launcher asks.
4. Boot the game so it registers the settings, then open the mod's options.
   Return to the launcher after boot if its settings list needs refreshing.

Typical Windows location (use your game's user-data directory on other devices):

```text
%APPDATA%\pokemon-love2d\mods\static_camera
```

Builds do not automatically install or modify an existing mod. Download the
release ZIP, not GitHub's source-code archive, for installation.

## Settings

| Setting | Choices / range | Default |
| --- | --- | --- |
| Camera mode | FULL, BOUNDED, NORMAL | FULL |
| Zoom basis | NORMAL (consistent), AREA FIT (area-relative) | NORMAL |
| Bounded zoom % | 5-200%, in 5% steps | 200% |
| Area framing | SCENE (full scene), TERRAIN (reachable crop) | SCENE |
| Crop padding | 0-4 map tiles | 1 |
| World resolution | RETRO, SCREEN | RETRO |
| Void backdrop | BLACK, GAME | BLACK |
| Area transition | NONE, FADE, H-SCROLL, V-SCROLL | FADE |
| Transition ms | 50-2000 ms, in 50 ms steps | 350 ms |
| Scroll direction | NORMAL, REVERSE | NORMAL |

Settings are read live. The engine owns saving them. Area framing is
independent of camera mode, so either framing choice works with Full or Partial.
The menu groups camera and zoom first, area framing next, rendering quality
after that, then transitions. Labels fit the engine's 18-character label and
8-character value limits rather than being silently truncated.

### Select-help

Highlight any Static Camera setting and press the game's **Select** button.
A `Select:HELP` hint appears below this mod's option rows.

- Read the setting's purpose, choices, applicable camera modes and limitations.
- Use **Left/Right** (or **Up/Down**) to change pages; the title shows the page count.
- Press **B** or **Select** to close. Help is modal: inputs cannot change the
  underlying setting while it is open.
- **Reset Defaults** has help too; opening its help does not reset anything.

Use your configured Select binding (by default, keyboard Tab or Shift).
The panel is implemented by a mod-scoped internal adapter because engine 0.3.19
has no native per-option help field. It does not add help to other mods' settings
or alter their shared manager class.

### World resolution

**Retro** keeps the original low-resolution rendering: the complete camera
view is drawn into the engine's small world canvas and enlarged with nearest
filtering. This preserves the chunky, pixelated zoom-out aesthetic and is the
default, including when updating an existing installation.

**SCREEN** (Screen Resolution) draws the world directly at the current game viewport's
physical pixel dimensions, including HiDPI scaling. It bypasses the small world
canvas for final presentation, reducing detail lost when fitting a large area
on screen. This is genuine higher-resolution world rendering, not a blur filter
or an enlargement of the already pixelated image.

- Works with Full Static and Partial, either framing choice, and all transitions.
- Dialogue, menus and other UI retain the engine's normal resolution and scale.
- Original pixel art stays pixel art; it does not invent new texture detail.
  Areas larger than the physical screen may still lose fine detail.
- Resizing the game viewport recreates the image buffers. A buffer resize or
  resolution change ends any in-progress camera transition, without recomputing
  the cached entry crop.
- Three RGBA image buffers use approximately **24 MiB at 1080p** or **95 MiB
  at 4K**, in addition to engine/map resources and the world-pixel staging buffer
  described below. Larger screens increase GPU work.
- If the screen exceeds the GPU/camera size limit, allocation fails, or the
  required world presentation path is unavailable, the mod logs a warning and
  retains the Retro camera. It does not replace another owner's world override.
  A failed allocation is retried after the pixel dimensions change or the
  camera is reset, for example by switching to Normal and back.
- Normal mode and protected presentations keep their original rendering.
  The engine's mirrored/capture preview remains low-resolution; the main game
  view uses the screen-resolution image.

To enable it, set **World Resolution -> SCREEN** in the mod options.
Choose **Retro** whenever you prefer the original appearance or lower GPU cost.

### Void backdrop

Set **Void Backdrop -> GAME** to use the pattern selected by the game's
**Extras -> Void Fill** option in empty margins around the framed area,
including the corners around a tilted map. **BLACK** is the default and
preserves the previous appearance.

- Follows the engine's **MAP, TREES, WATER and BLACK** selection rules. MAP uses
  the current map's own repeating border.
- TREES/WATER require a compatible primary tileset and available metatiles.
  Otherwise the game falls back to the map border; this mod does too. Some
  interiors can therefore remain black even with GAME selected.
- The pattern is anchored to world coordinates. With Tilt enabled, it uses
  **the same perspective ground plane and shader as the map**, including its
  depth scaling and centering. Flat mode keeps nearest-filtered repetition.
  This is visual fill, not loaded neighboring terrain: it does not move camera
  bounds or replace black tiles authored inside the map.
- In tiny rooms at high Tilt angles, the ground horizon can enter the viewport.
  Space above it remains black rather than stretching or flipping terrain over
  the horizon. A half-pixel guard below the horizon avoids invalid projection.
- The pattern follows live Extras changes and atlas animation/recolouring.
  Outgoing/incoming transitions retain each area's own backdrop; UI stays above it.
- Borders are assembled at integer 1:1 tile coordinates before repetition to
  avoid packed-atlas seams. The small repeat texture counts toward the camera
  buffer budget; an optional backdrop allocation failure logs a warning and
  keeps the camera working with black margins.
- NORMAL uses the engine's unmodified rendering and Void Fill behavior.

Select-help on **Void Backdrop** explains these choices in the menu.

### Tile seams while moving

The field is assembled at **one texel per world pixel**, using an integer camera
origin and a small cropped-out guard border. The completed image is then scaled
to the selected camera view. This follows vanilla's rendering order and avoids
sampling neighboring cells of a packed tile atlas at fractional zoom boundaries.

It does not blur the image or squeeze the map into a small canvas before Screen
output. Screen Resolution still samples the full-detail world image directly
into the physical viewport. Natural nearest-neighbor pixel shimmer at fractional
scales may remain, but unrelated tile colors should no longer leak between tiles.

The reusable staging buffer costs about four bytes per visible world pixel,
plus its guard border; its size depends on the visible area, not screen resolution.
At extreme map sizes it can reach roughly 32 MiB or hit the GPU's texture limit.
SCREEN buffer failures first retry in RETRO, keeping the selected camera and
Tilt. If even the lower-resolution path cannot allocate its world buffer, the
mod logs the failure and preserves vanilla rendering rather than publishing
an incomplete field image.

### Full Static (FULL)

Fits the entire selected rectangle uniformly into the viewport, centered over
the selected backdrop (black by default). Ordinary movement inside that rectangle does not move the camera.
Interiors use their own map layout, never surrounding connected-world bounds.
Different map/screen aspect ratios produce deliberate backdrop margins, not a
view of neighboring maps.

### Partial / Bounded (BOUNDED)

Uses the selected rectangle as independent horizontal and vertical camera
limits. The camera follows while there is room, then stops at each boundary.

**NORMAL zoom basis** (Consistent, the default) makes the percentage a multiplier of the normal
engine camera scale, independent of map size:

- **100%** matches normal engine zoom; **200%** draws world pixels twice as large.
- **50%** draws at half the normal scale, showing twice the width and height
  when the area is large enough. Values down to **5%** are selectable in **5%**
  steps. Higher percentages zoom in; lower percentages zoom out.
- Moving between differently sized areas keeps the same apparent character/tile
  size, provided each area can contain that viewport.
- Small or narrow areas automatically increase zoom only as much as necessary
  to keep both axes inside the selected bounds. That safety rule takes priority
  over constant size, including when using Reachable-Area Crop.
- The normal engine zoom setting and window fit remain the baseline. Changing
  those can still change the apparent size; changing only the map does not.
- Retro and Screen Resolution use the same physical scale, including HiDPI.
  Retro's rounded viewport can cover a few extra edge pixels, so the boundary
  clamp can differ slightly from native output in very small areas.

**AREA FIT zoom basis** (Area Relative) preserves the previous behavior: the percentage multiplies
the whole-area fit. Larger areas therefore show smaller characters at the same
percentage. Boundary zoom/clamping still applies.

Both styles use the same percentage setting, now limited to **5-200%**. Existing
values outside this range are clamped; valid saved values and the default 200%
are retained. The options screen saves the corrected value. Select **AREA FIT**
for the earlier percentage interpretation, or choose **NORMAL + 100%** for a
bounded camera at normal zoom. A boundary-limited view can stop getting wider
even if you lower the percentage further; use FULL to show the entire area
with black bars rather than revealing outside space. Full Static always fits the whole
area and is unaffected by either Partial zoom setting.

### Area framing toggle

**SCENE** (Full Scene) preserves the complete authored map rectangle: walls, trees,
water and decorative regions remain visible. This is the default.

**TERRAIN** (Reachable-Area Crop) performs a bounded traversal of the active map's terrain,
starting at the player's entry position, then frames the resulting rectangle:

- Uses the installed engine's walkability, directional barriers, ledge landing,
  water and elevation queries; never attempts actual movement or triggers a warp.
- Includes connected water as potentially traversable, even before Surf is
  unlocked. It does not evaluate the player's badges, party, keys or HM access.
- Ignores temporary NPC occupancy and story-object blockers. This is a
  **terrain-connected crop**, not a progression/pathfinding guarantee.
- Directional ledges may include their reachable landing region. Traversal
  stops at this map's boundaries and does not follow doors into another map.
- Padding adds scenery around the crop and stays inside the layout. One tile
  is the default to leave room around character sprites and walls.
- The rectangle is cached on entry, not recalculated around every player step.
  Changing framing/padding or map/layout rebuilds the crop.
- If a same-map teleport, new passage, or unusual movement places the player
  outside the cached rectangle, it expands with a warning rather than hiding
  the player. This is an explicit exception to stationary framing.

Neither choice cuts a map into an irregular silhouette. Unreachable scenery,
holes or decorative black cells **inside** the selected rectangle can remain.
The crop is not guaranteed to be the smallest visually pleasing interior.
Full Scene is the predictable alternative if the crop is unsuitable for a map.

### Transitions

The adapter retains the last rendered field image. On a direct map change it
renders the destination using the new camera and composites the two views:

- **Fade Through Black:** outgoing image fades out, black midpoint, destination
  fades in. Duration covers both halves.
- **Horizontal / Vertical Scroll:** outgoing and incoming images slide together;
  Scroll Direction -> REVERSE reverses the axis direction. Direction is user-selected, not
  inferred from a door's orientation.
- **None:** switch directly to the destination frame.

Repositioning is hidden visually. Simulation is **not paused** or postponed:
the map may already have changed while the outgoing snapshot fades. Engine-owned
script fades, battle transitions and other special presentations still run.
This is not a replacement for their script timing.

**Doors and warps do not play a second mod transition.** When an engine warp or
screen fade is active (including a held black/white screen), the adapter
positions the new camera under that cover and skips its own animation.
The game's door fade and timing remain intact. The selected camera transition
still applies to ordinary area changes without an engine-owned transition.

### Tilt

Use the **game's existing Tilt setting**; no separate mod toggle is required.
FULL and BOUNDED now render perspective ground with separately drawn upright
characters, rather than tilting a flattened screenshot.

- **FULL:** the selected area's projected corners remain visible, with room for
  upright sprites. The view remains stationary while walking. Perspective
  naturally leaves margins around the projected map silhouette, filled by the selected backdrop.
  Framing uses player/map-actor sprite sizes, not the engine's large offscreen
  canvas padding. The per-area sprite envelope only grows if a larger actor
  appears; that exceptional reframe is logged. Missing actor metadata uses a
  conservative fallback.
- **BOUNDED:** the camera clamps the inverse-projected viewport footprint to
  the area. Tilt can require a higher minimum zoom, especially in narrow areas.
- Works with both resolution modes, framing choices and camera transitions.
  Dialogue and menus stay at their normal size.
- Changing Tilt angle, mode or zoom discards a transition's old projection so
  the next view does not mix incompatible camera images.
- The ground uses the engine's perspective shader and its normal linear ground
  filtering. Flat rendering keeps nearest filtering; sprites remain upright
  at the camera scale instead of being flattened or depth-scaled with the floor.
- If the audited shader/mesh is unavailable, the mod logs a warning and retains
  a flat camera. Saved Tilt preferences are not changed.
- Tilt adds an upright image buffer. The mod targets a **128 MiB canvas budget**;
  SCREEN falls back to RETRO with a warning if its combined buffers exceed that
  budget or allocation fails. Tilt remains active in the fallback. This budget
  does not include the engine's own textures or other mods' resources.

### Normal and protected presentations

Normal calls the original draw path and releases mod-owned canvases, preserving
the engine's ordinary camera and Tilt. Full and Bounded compose their own flat
or perspective view. The engine's automatic Tilt pass is bypassed only during
that draw to avoid projecting the completed mod image twice.

Explicit shop/special cameras, camera panning, hidden-actor cutscenes, battle
transitions, visible hardware backgrounds and deferred world-OAM overlays
retain the original field renderer. Those protected views are exceptions to
static framing/isolation, not claimed implementations of it. Ordinary dialogue
alone does not disable the camera. The UI continues to be drawn by the engine.

Other mods replacing the same renderer, panning or presentation functions have
not been certified together.

## How the adapter works

- `geometry.lua` owns projection, rectangle traversal and transition math,
  independently of engine internals.
- `tilt_geometry.lua` fits the projected area and clamps inverse-projected
  viewport bounds. `tilt_render.lua` reuses the installed engine's perspective
  shader/mesh and projects actor feet in a separate upright pass.
- `adapter_gen3.lua` owns the version-specific renderer integration. It wraps a
  game instance through the existing `core.update` hook, not a fork-only hook.
- `settings_help.lua` adds scoped Select handling to the active FRLG manager
  instance and a mod-owned, paginated help layer. Closing/recreating the manager,
  resetting the game, quitting or disabling the mod cleans up its owned hooks
  and help layer. Old zoom values are normalized through the engine's existing
  option-save method, not a separate settings store.
- `void_backdrop.lua` uses the engine's Void Fill selector and the active
  tileset to build a small repeating background. It does not change the saved
  Extra option or register neighboring maps in the rendered world.
- Only during a synchronous field draw, it cancels the internal player-follow
  calculation through temporary camera panning. Player/world simulation state
  is not repositioned.
- Connected-map sampling and neighbor actors are excluded during that draw.
  Drawing goes into a clipped mod-owned canvas. Black margins are intentional.
  The connected world, sampling functions, panning, Flash projection and
  graphics state are restored even when rendering throws.
- Camera-dependent tile batches are separate from vanilla's batches.
  Invalidations propagate without keeping stale caches when returning to Normal.
- Screen Resolution uses the audited renderer's `frameRects()` physical pixel
  dimensions and `setWorldOverride()` composition path. Engine UI and world-fade
  composition remain in place; a downscaled preview also feeds its world canvas.
- Reset, quit-to-launcher and removal of the owning mod hook detach the wrapper
  and release canvases. Draw failures are logged and propagated, not silently
  reported as successful renders.

Upstream references:

- [Development documentation](https://github.com/bryanthaboi/gen1recomp/tree/dev/docs)
- [Official modding wiki](https://github.com/bryanthaboi/gen1recomp/wiki)
- [Audited source revision](https://github.com/bryanthaboi/gen1recomp/tree/e7ce2a3a7195dc4f5f7d6177cddc736afcd0ff66)

Validation used source modules extracted from the installed **0.3.19** update,
not the older executable's 0.2.58 payload or the modified local development
fork. Future supported hooks can replace the adapter while retaining geometry,
settings and acceptance tests.

## Build

The runtime mod is Lua-only. Packaging needs PowerShell 5.1+ on Windows; it
does not compile Lua or require Python, engine files, ROMs, or imported assets.
From the repository directory:

```powershell
.\build.ps1
```

Alternatively, run the **Build mod ZIP** VS Code task. The script reads the
version from `manifest.json`, packages an explicit runtime/documentation
allowlist at the ZIP root, checks every archived file against its source, and
writes `dist\static_camera-<version>.zip` with a `.zip.sha256` checksum.
Archive timestamps are fixed for repeatable packaging of unchanged inputs.
Tests, local agent profiles and build tooling are not included in the mod ZIP.

GitHub Actions performs the same packaging and uploads a downloadable artifact
on pushes to `main`, version tags, or a manual workflow run. This is a
**packaging check only**; it does not run the engine-dependent tests below.

## Validation

- **6192/6192 headless assertions passed** with the installed LuaJIT library,
  installed 0.3.19 modules and the upstream `tests.modkit` harness.
- **12112/12112 assertions passed under real LÖVE 11.5 graphics**, including fitted
  terrain pixels, black margins, Partial's filled viewport, the black fade
  midpoint, and distinct outgoing/incoming images in both scroll axes.
- The actual final `Renderer:endFrame()` compositor was tested at normal and
  2x DPI. A one-pixel stripe fixture retains **more than twice the adjacent
  color changes** in Screen Resolution versus Retro after final composition,
  proving the native image is not downsampled again. UI position/width/color,
  black margins, resizing, engine fades, native camera transitions and
  post-publication error cleanup are covered.
- Screen-size limits, allocation-failure fallback/retry suppression, other
  override ownership, Normal and unsupported presentation paths are covered.
- Consistent-zoom tests cover map-independent scale, all four bounds, narrow
  areas and unchanged Full Static. Final GPU output keeps exact stripe widths
  across two map sizes, 100/200% zoom, normal/survey engine zoom, both resolutions,
  1x/2x DPI and even-rounded world viewport sizes. Small-area corner pixels stay
  filled, and Area Relative retains its previous map-dependent scaling.
- 5/25/50% zoom, legacy percentage clamping and unchanged area bounds are covered.
- Actual engine fade state drives door-arrival GPU tests in Retro and Screen
  rendering, with all three configured camera effects. The destination fades
  in once, with no delayed second effect; held script cover is covered too.
- Settings tests use the actual manager and UI stack with synthetic drawing
  sinks: every row has help, pages fit the panel, Select/B close correctly,
  modal input cannot edit settings, other mods are untouched, and saved zoom
  migration uses the normal save/event path. Imported-font appearance still
  needs an in-game visual check.
- Tilt tests compare forward/inverse geometry against the installed engine,
  then check real GPU corner coverage, bounded edges, upright sprite height
  and feet, normal/2x DPI, both resolutions, angle changes and transitions.
  The audited mirrored-override path is simulated on the GPU; this is not a
  claim of testing an actual iOS device.
- Small-room fitting, large-actor envelopes, grow-only sprite clearance,
  shared-mesh error cleanup and SCREEN-to-RETRO resource fallback are covered.
- Void backdrop tests cover engine MAP/TREES/WATER/BLACK selection and fallback,
  repeated border phase without atlas leakage, both resolutions and HiDPI,
  Tilt margins, authored black tiles, unchanged capture bounds/UI, retained
  outgoing/incoming backgrounds and optional allocation-failure recovery.
- Perspective fill regression checks compare final pixels to the inverse ground
  projection at 15, 35 and 50 degrees, in Retro, SCREEN and SCREEN at 2x DPI.
  All 18 per-game/view/angle cases failed with the old flat backdrop and now
  pass. Tiny-room tests also cover a visible horizon without inverted terrain.
- Both FireRed and LeafGreen loader targets were exercised.
- Includes 400 bounded projection cases across aspect ratios/zoom settings,
  framing-toggle/crop-padding tests using actual collision functions, renderer
  state restoration, injected draw failures and disable cleanup.

These tests use **original synthetic map/graphics fixtures** with the actual
installed FieldView, collision and loader modules. They do not establish
full-playthrough compatibility, imported-map appearance, real actor/effect
placement, large-map performance, or correct interaction with every cutscene.
No Python tools or environment were used.

The user reported working gameplay in earlier releases and supplied a tile-seam
screenshot. The seam fix and new Tilt implementation still need imported-map
gameplay and performance checks, especially sprite occlusion, weather and Flash.

For reproduction, use the installed target's extracted Lua modules and a clean
upstream test harness on Lua's module path, with the installed modules first.
With `LUA_PATH` configured that way:

```powershell
luajit .\tests\camera_test.lua (Get-Location).Path
```

Do not substitute the old local fork or change the engine version constant to
make this test pass. The GPU variant runs the same test under LÖVE with
`love._staticCameraGpu = true`; fixtures then use generated textures and pixel
assertions rather than a graphics stub.

## In-game smoke tests still required

On **both FireRed and LeafGreen**, using a save with free movement:

1. Pallet Town: Full + Full Scene, walk to all edges. The scene must stay fixed.
2. Player's house and Oak's lab: toggle Full Scene / Reachable-Area Crop and
   padding 0/1/4. Check scenery, doors and the player's whole sprite.
3. Bounded: both zoom bases at 5/25/50/100/200%, walking to all four edges.
   Compare character size across outdoor maps in Consistent; repeat in a narrow
   interior where the safety minimum must take priority.
4. Pallet Town / Route 1 and house doors: all transitions, both scroll directions
   and duration extremes. Check rapid return crossings and existing door fades.
5. Dialogue, a Poke Mart buy menu, healing, a battle, scripted movement, and
   returning to free movement: protected presentations and UI must remain usable.
6. Rock Tunnel: darkness and Flash's aperture must stay attached to the player.
7. Surf, ledges, bridges, Cut/Strength changes and same-map teleports: verify crop
   usefulness and documented expansion behavior.
8. Change window aspect ratio, toggle Normal/Tilt, disable/re-enable and return
   to the launcher. Check errors and GPU memory/performance on large maps.
9. Toggle Retro / Screen Resolution in Full and Partial, with dialogue open,
   then across each transition. Resize the window and test the monitor's DPI
   scale. Check world detail improves without changing UI size.
10. Open Select-help for each setting and Reset Defaults. Page through it and
    close with B/Select; confirm the underlying value does not change. Compare
    door entry/exit against a seamless outdoor crossing: doors should play only
    the engine transition, not a second fade or scroll.
11. Enable the game's Tilt setting and test FULL/BOUNDED at multiple angles,
    outdoors and inside small rooms. Walk to all four edges, compare sprite
    height/occlusion, and test animated NPCs, doors, weather and Flash.
12. Switch Void Backdrop between BLACK and GAME, then try each Extras Void Fill
    mode outdoors and indoors. Check that fill matches the map's Tilt angle and
    depth at all angles, including tiny-room horizons. Check transitions and
    that actual black map tiles remain unchanged.

Rendering is capped at 32768 layout metatiles and 8192 pixels per viewport
axis (or the GPU's lower texture limit for screen-resolution buffers).
Screen-resolution allocation failures warn and fall back to Retro. Unsupported
layouts or failure to allocate even Retro canvases preserve vanilla rendering.
Smaller layouts may still be expensive
to draw fully. Use Partial if large areas are too slow or visually tiny.
