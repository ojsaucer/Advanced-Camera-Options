# Technical reference

For features, installation and everyday settings, start with the [README](../README.md).
This page contains the implementation details intentionally kept out of the project overview.

## Compatibility

The Lua runtime targets FireRed and LeafGreen, mod API 2. Engine versions
**0.3.19 and 0.3.22** have passed the camera regression suite.

The manifest admits `>=0.3.19 <0.4.0`. The runtime additionally rejects development
and prerelease version strings. Stable versions outside the tested pair require
the explicit `UNTESTED ENGINE -> TRY` opt-in; the default is OFF.
Different engine families or mod API majors require a new compatibility audit.

`compatibility.lua` centralizes version policy and required module/method checks.
Missing core requirements leave the original camera active. Optional failures
can select Retro, flat projection, full-scene framing, black fill or no Select-help.
Backdrop shading is checked independently. Fallbacks do not rewrite preferences.
Restart after updating missing capabilities.

These checks cannot establish unchanged semantics in future engine internals.
The mod requires `engine_internals`, not a stable public camera API.

References:

- [Upstream developer documentation](https://github.com/bryanthaboi/gen1recomp/tree/dev/docs)
- [Official wiki](https://github.com/bryanthaboi/gen1recomp/wiki)
- [Original audited source](https://github.com/bryanthaboi/gen1recomp/tree/e7ce2a3a7195dc4f5f7d6177cddc736afcd0ff66)
- [0.3.22 source](https://github.com/bryanthaboi/gen1recomp/tree/5540fc1538c7c9c8a3c8c85e09679ae03f28beaf)

## Rendering

- `geometry.lua` implements flat framing, terrain traversal and transition math.
- `adapter_gen3.lua` attaches through `core.update` and wraps the active game
  instance. Normal mode delegates to the engine.
- Only during a synchronous field draw, the adapter isolates the current map
  and temporarily adjusts field panning, sampling, tile caches and Flash coordinates.
  Player/world simulation state is not moved. With connected context enabled,
  a render-only list of direct neighbors replaces isolation; world-cache metadata
  and the original neighbor list are restored after the draw.
- Tiles are first assembled at integer world-pixel coordinates into a staging
  canvas. Guard pixels prevent packed-atlas seams during fractional scaling.
- SCREEN uses physical viewport dimensions and the engine's world override.
  A low-resolution preview remains available to engine mirrors/captures.
- SCREEN FILTER defaults to CRISP. SMOOTH uses derivative-aware terrain sampling
  with mipmaps for minification, while enlarged terrain samples nearest texel
  centers. Mipmap storage counts toward the canvas budget. Repeat backdrops use
  linear minification and nearest magnification on assembled canvases, never on
  packed atlases. Owned backdrop filters reset after draws, including failures;
  borrowed terrain/mesh texture state is restored. Retro and Normal are unchanged.
- The 0.3.22 cell-list/pool scratch state is isolated alongside tile batches.
- A mod draw error restores scoped state, is logged and propagates. It is not
  hidden or retried midway through the same frame. A faulted camera uses the
  original draw path on subsequent frames.

Special shop cameras, camera panning, hidden-actor cutscenes, over-UI transitions,
hardware backgrounds and deferred world overlays retain the original field
renderer. Ordinary dialogue does not disable the camera. Other camera-replacement
mods have not been certified together.

## Bounds, cropping and zoom

SCENE uses the authored map rectangle, including decorative terrain. TERRAIN
uses terrain-connected traversal from the entry tile, includes water and does
not model HM availability, progression or temporary NPC blockers. Padding is
clamped to the current map. Exceptional movement outside a cached crop can
expand it, with a warning.

Consistent zoom uses scale 1 in Retro and the engine's exact physical world scale
in SCREEN. Area-relative zoom multiplies the whole-area fit. With MAX ZOOM off,
both enforce a minimum scale to contain the viewport. The optional ceiling uses
normal-engine scale independently of the zoom basis and overrides that minimum.
Undersized axes are centered, with only actual terrain composited over the backdrop.

Hybrid multiplies Full's fit by its own 100-200% zoom and follows the player on
both axes. Only Full's limiting axis is clamped; ties constrain both. Tilt uses
the projected actor envelope to identify the limiting axis, then scales Full's
projection and focal distance together before panning. Bounded basis, zoom and
ceiling settings do not affect Hybrid. Connected capture and map shading are
shared by Full, Full-Scroll, Hybrid and Bounded, and never determine their
initial fit or reposition the camera on their own.

FULL-SCROLL reuses the Hybrid flat/Tilt projection code paths with its zoom
fixed at exactly 1 (no exposed zoom setting), so it shares Hybrid's limiting-axis
detection and clamping and is otherwise identical to Full's fit and scale.

The mod limits layouts to 32768 metatiles and viewports to 8192 pixels per axis
or the GPU's lower texture limit. It targets a 128 MiB budget for its own canvases,
excluding engine textures and other mods. SCREEN allocation failures can retry
in Retro without changing the saved resolution choice.

## Tilt and sprites

`tilt_geometry.lua` fits projected Full bounds and clamps Bounded views using
the inverse-projected viewport footprint. `tilt_render.lua` reuses the engine's
perspective shader/mesh and draws upright actors separately.

Actor width and height are multiplied by the perspective factor at their feet.
The scoped adapter checks the native project/push/translate handoff, applies
scaling inside that actor's matrix push, then restores projection/translation
hooks. Sprite-local animation transforms remain intact. Full fitting includes
the depth-scaled actor envelope; that envelope can grow if larger actors appear.

**The strict Bounded corner limitation is intentional and unchanged.** The
footprint's wider far edge can prevent the camera moving far enough to include
the map's lower corners. Full-player visibility is not guaranteed there.

## Void Fill and effects

`void_backdrop.lua` follows the engine's MAP/TREES/WATER/BLACK selection rules.
Unsupported tilesets fall back to the map's border. A small repeating texture
is rebuilt at integer coordinates for live atlas changes, then projected in
world space when Tilt is active. It never registers neighboring maps.

Uniform forest shade is applied once to each freshly rendered border texture,
using the native weather renderer. Weather suspension is respected. Global
compositor fades and veils remain engine-owned.

Spatial fog, rain, cave Flash masks and local field effects are not replayed
onto the repeated border. Space above a visible ground horizon stays black;
a half-pixel guard avoids the inverse projection's singularity.

## Transitions and help

Transitions retain outgoing and incoming field images. Simulation is not paused;
the map may already have changed while its previous image is fading out.
Engine-owned door, warp and script fades remain intact and suppress duplicate
mod transitions. Changes in projection or output size discard incompatible
transition images.

`settings_help.lua` adds help only to this mod's live FRLG options screen.
Select opens help, directional inputs change pages, and B/Select closes it.
The shared manager class is not modified. Existing out-of-range zoom values
are normalized through the engine's option-save mechanism.

## Build and validation

From the repository directory on Windows, run:

```powershell
.\build.ps1
```

The **Build mod ZIP** VS Code task runs the same script. PowerShell 5.1+ packages
an explicit runtime/documentation allowlist and verifies each ZIP entry against
its source. The output includes a SHA-256 checksum and fixed archive timestamps.
No Python, engine modules, ROMs or imported assets are included.

GitHub Actions checks packaging and uploads an artifact. It does not run the
engine-dependent rendering tests.

The v0.10.0 camera code passed:

| Engine | Headless assertions | Real LÖVE 11.5 graphics assertions |
| --- | ---: | ---: |
| 0.3.19 | 6,421 | 12,992 |
| 0.3.22 | 6,421 | 13,004 |

Tests use actual extracted engine modules with original synthetic fixtures.
Coverage includes bounds, zoom, resolution, HiDPI, tile seams, shade, transitions,
near/far sprites, foot anchoring, settings-help and failure cleanup. The mirrored
override path is simulated, not a claim of actual iOS certification.

To run the Lua suite, put the matching engine modules first on `LUA_PATH`,
followed by the clean upstream `tests.modkit` harness, then run:

```powershell
luajit .\tests\camera_test.lua (Get-Location).Path
```

The GPU variant runs the same suite under LÖVE with `love._staticCameraGpu = true`.
Full playthroughs, imported-map appearance, every actor/effect, large-map
performance and combinations with other mods still need in-game testing.

### Release and launcher checks

Version 0.10.1 adds top-level `manifest.github` for the engine-owned updater.
It needs no mod network permission. The eight runtime Lua modules are unchanged
from 0.10.0.

`tests/release_test.lua` validates an extracted runtime ZIP with the actual engine
manifest and updater modules. An optional second argument supplies the public
GitHub releases JSON instead of the offline fixture:

```powershell
luajit .\tests\release_test.lua C:\path\to\extracted-mod C:\path\to\releases.json
```

The 16 metadata/selection checks pass on both tested engine versions. The 0.3.22
launcher installer was also exercised under real LÖVE in an isolated user-data
profile: clean ZIP import, replacement through `installDownloadedZip`, unchanged
saved options, repository discovery and byte-for-byte installed-file checks.
Repeated replacement reproduced the engine's directory-cache defect; a new
process recovered successfully. No real installation or save was used.

The updater prefers a stable release, falling back to a prerelease if no stable
release exists. It uses release assets, not Actions artifacts or GitHub source
archives. Its ordinary update path does not automatically verify the separate
SHA-256 sidecar. Public release checks should verify the selected asset, download
hash and packed metadata separately.

## 0.11.0 camera and preview changes

- Connected context retains primary fit inputs. Direct placements use the native
  connection directions, offsets and layout sizes. Terrain is clipped per map,
  rather than drawing an opaque rectangle over gaps between neighbors.
- Slides consume `map.entered` connection events. Ambiguous directions use the
  crossing facing only if it matches a connection; unknown directions do not
  slide. Legacy horizontal/vertical values are accepted and normalized in options.
- Ordinary battle entry keeps the mod projection and downsamples into the native
  world canvas. No unprocessed Screen override bypasses the native effect.
  Effect timing, callbacks and UI composition remain engine-owned.
- Start-preview replaces only this mod's options drawing. It calls the adapter's
  render-only entry point, not `game.draw`, and does not change stack fullscreen
  flags. B restores the unchanged menu. Current settings are rendered afresh.

Validation with both actual engine module sets and original synthetic fixtures:

| Engine | Headless camera | Preview UI | Real LÖVE graphics |
| --- | ---: | ---: | ---: |
| 0.3.19 | 7,303 | 149 | 15,378 |
| 0.3.22 | 7,303 | 149 | 15,390 |

Graphics coverage includes capped interiors with BLACK/GAME fill, offset neighbor
tilesets and gaps, four slide directions, native mask/redraw/battle effects,
unchanged battle framing and callbacks, and the actual preview renderer.
Imported battle chrome/assets and every gameplay scene still need in-game testing.
Run `tests/preview_test.lua` separately with the same headless harness paths;
the camera suite includes the graphics feature tests when run under LÖVE.

## Boundary presentation

Full-specific controls precede Bounded-specific controls, followed by shared
framing, appearance, transitions and compatibility. Existing option keys remain
unchanged; no unsupported menu-group schema fields are introduced.

`boundary_shading.lua` temporarily wraps only draws of the field renderer's native
under/over terrain batches. Its world-coordinate shader excludes the primary
map rectangle and does not intercept actor or UI images. Uniform shading applies
the chosen opacity; gradient shading uses Euclidean distance from the primary
rectangle, reaching that opacity at the configured distance. A one-world-pixel
guard outside the primary edge prevents dark texels bleeding onto primary terrain
when the assembled tilted raster is linearly filtered. Hooks and shader state are
restored after errors. Unsupported shaders leave original colors with a warning.

Connected scenery does not participate in projection fitting or its invalidation
signature. If allocating the enlarged optional raster fails, the adapter retries
the primary-only raster at the same output resolution and projection. The failure
is remembered for that map/layout/output size; toggling connections off and on
allows a retry. It does not set the camera fault or Screen-fallback latch.

EXTRUDE uses eight reusable edge-strip/corner canvases rather than a huge
outside-map raster. Sampled tile indices run from the boundary inward and repeat;
pixel orientation inside each tile is unchanged. Strip depths clamp independently
to authored width/height. Integer atlas assembly, live repainting and uniform
weather shade happen before region-specific flat or perspective projection.
Only the eight outside regions are drawn; actual primary/neighbor terrain retains
precedence. `desc.pixels` accounts for the complete set of strip allocations.
Above-horizon space remains black.

Validation on both actual engine module sets with synthetic fixtures:

| Engine | Headless camera | Preview UI | Real LÖVE camera |
| --- | ---: | ---: | ---: |
| 0.3.19 | 7,740 | 149 | 122,135 |
| 0.3.22 | 7,740 | 149 | 122,147 |

Separate extrusion checks pass 1,175 CPU and 58,330 real LÖVE assertions per
engine. Coverage includes repeated strips and corners at multiple depths,
flat and tilted projection, adapter-selected EXTRUDE in capped rooms,
neighbor-only uniform/gradient shading, brightness after entering a neighbor,
and unchanged primary framing when optional neighbor allocation fails.
These fixtures do not replace gameplay checks with imported game assets.

## 0.12.1 boundary corrections

- EXTRUDE uses BLACK for indoor definitions and engine map types 4, 8 and 9
  (underground, indoor and secret base), matching the importer's indoor grouping.
  Repeating authored black/decorative interior tiles is avoided rather than
  substituting guessed wall art. GAME and Normal behavior are unchanged.
- Flat coverage scissors round both endpoints to pixel-center coverage before
  deriving width and height. Independent truncation of fractional position/size
  left uncovered pixels between the raster and extrusion. Reinstating the old
  scissors reproduces 520 failed assertions in the new GPU suite.
- Backdrop shading runs once after the backdrop is projected, before terrain
  and sprites are composited. It shares the terrain shader's distance function
  and edge guard, using inverse Tilt projection to get each pixel's world
  position. The gradient never repeats with the texture or steps per tile.
  The existing repeat canvases remain: no per-frame tile-mesh rewrite or
  unverified texture-wrap workaround is needed.
- Only terrain sampling temporarily sees connected placements in `Map.world`.
  Actor collection sees just the active map, preventing neighbor sprite requests
  before rendering. Changing exported `Field.applyDrawOrder` would not suffice:
  both tested engines call their local function directly. World state still
  restores on rendering failure; no simulation state or engine file is changed.

GPU regressions cover indoor/outdoor changes, primary actor collection without
neighbor requests, uniform/gradient shading on both neighbors and GAME/EXTRUDE,
and map/extrusion joins at depths 1, 2, 8 and 16 in flat and 15/35/50-degree Tilt
views. Fractional viewport fits include 719x481, 999x333 and 1360x768.

Final checks against actual engine modules (synthetic assets):

| Engine | Headless camera | Preview UI | Real LÖVE camera |
| --- | ---: | ---: | ---: |
| 0.3.19 | 7,811 | 149 | 236,406 |
| 0.3.22 | 7,811 | 149 | 236,418 |

The separate extrusion suite still passes 1,175 CPU and 58,330 GPU checks
per engine. The reported gameplay locations and Android hardware were not
replayed in this validation.

## 0.13.0 content-aware extrusion

`scenery_patterns.lua` recognizes a deliberately limited General-primary
metatile vocabulary. These are metatile IDs, not adjacency in a packed atlas.
The rules were visually checked using the player's locally imported FireRed
General under/over atlas. No extracted artwork or game data is shipped.

- Tree motifs come from `VoidFill.borderFor("trees")`; the imported Pallet border
  is `[01C,01D;014,015]`. Each boundary tile fixes the phase of that motif, so
  continuation completes the neighboring halves instead of mirroring pieces.
  Verified outer canopy `00C/00D` and trunk `024/025` variants map to those phases
  only when that exact canonical source is present.
- Ocean fill comes from `VoidFill.borderFor("water")` (Cinnabar, normally
  `1D9`). Recognized water-rock quarters `110/111/118/119` and
  `1CB/1CC/1D3/1D4`, plus the explicit open-water family, use that fill.
- The explicit shoreline table records which directions face water. Extensions
  in those directions get one finite row of the verified open coastal-water
  transition `12B`, then ocean. Land-facing and unsupported orientations keep
  the strip fallback. This is not a general shoreline generator.
- Every replacement motif must exist in the current atlas via `Native.hasMid`;
  `slotFor`'s silent slot-zero substitution is never used to validate a pattern.
  Missing source maps, incompatible primaries and unrecognized pieces preserve
  existing strips. A missing coastal transition preserves shoreline strips.

The eight existing repeat regions use the least common multiple of the fallback
strip and recognized motif periods. Thus changing EXTRUDE DEPTH never truncates
a tree, and unknown strips retain exactly their original sequence. Eight bounded
one-tile rim regions carry only finite shoreline completions; transparent cells
leave the base fill alone. All canvases remain included in the resource budget.
Native under/over assembly and repainting are retained, and weather shade applies
only to populated rim cells. The shared map-shade pass still runs afterward.

Synthetic tests cover edge/corner phase, all water-rock quarters, water-facing
versus land-facing shores, missing templates/atlas entries, mixed recognized and
unknown edges, depths 1/2/8/16, flat and 15/35/50-degree Tilt, and actual adapter
selection. GPU checks verify the finite coast never repeats and native uniform
shade is applied once. Other tree variants, custom tilesets and unlisted coastal
families intentionally remain strip-based.

Final validation: 8,541 headless camera checks and 149 preview checks on each
engine; 331,156 real-GPU camera checks on 0.3.19 and 331,168 on 0.3.22.
The separate strip suite adds 1,175 CPU and 58,330 GPU checks per engine.
Visual rule identification used locally imported FireRed art; gameplay in the
reported scene and LeafGreen-specific artwork were not replayed.

## 0.13.1 scenery edge cases

The reported Route 9/10, Route 13/18, Saffron and Viridian Forest boundaries were
checked against locally imported metatile IDs. General-primary rules now include
the small water-rock family `212/213/21A/21B`, the remaining water variants,
outer tree connectors, an explicit building-piece set and mountain pieces.
Buildings use the applicable tree motif; mountains use the verified plateau
center `071` only when it exists in the atlas. No source-map tiles are replaced.

Viridian Forest has a secondary 3x2 tree motif
`[298,299,29A;290,291,292]`. The resolver requires that entire authored border
signature and availability of every output MID before enabling secondary rules.
It does not assume that the same secondary IDs or a hard-coded ROM address
identify a forest in another tileset. The forest canopy, closing rows and base
variants have explicit phases; the forest gate trim uses this same local motif.
Combined repeat periods remain divisible by both tree widths and fallback depth.

The extra real-GPU cases cover forest phases, new water rocks, gate roofs and
mountain faces at depths 1/2/8/16 in flat and 15/35/50-degree Tilt. Unit cases
also reject incomplete atlases and near-matching but different forest borders.
The authored bottom-of-map detail identified by the user is intentionally
unchanged. These are synthetic regression checks, not a replay of the saves
shown in the screenshots.

Final GPU results: 449,160 camera checks on 0.3.19 and 449,172 on 0.3.22,
plus 58,330 separate extrusion checks per engine. Headless camera and paused
preview checks also passed on both engine module sets.

## 0.14.0 Hybrid, filtering and directional scenery

Wall classification now separates horizontal and vertical continuation. An
authored corner chooses the straight piece for the axis crossing the map edge;
an existing straight wall retains its artwork when extended parallel to itself.
Two-axis corner background and extensions perpendicular to a straight wall still
use plateau fill. Missing oriented replacements retain the existing strip
fallback, not an unrelated atlas slot. Explicit General families include both
grass-edged and rock-edged mountain walls and the concave `0B2/0B3` pieces.

The Seafoam boundary's mixed water/mountain pieces `10F/117/11F/129`, and water
variants `1DA/1E1`, now extend as ocean. Cerulean's water-facing crown pair
`10A/10B` and middle canopy `0FA/0FB` preserve their two-column phase along
horizontal extensions; the water-facing side becomes ocean. A partial crown
can complete on the finite rim before the dense tree repeat starts. Grass-facing
`00E/00F` crowns similarly keep their paired row. No actual map tiles are edited.

Hybrid regression coverage includes both limiting axes and ties, 100/150/200%
zoom, independence from Bounded controls, flat/Tilt edge behavior, connected
scenery, shading and paused preview. SCREEN filtering tests use synthetic
one-pixel patterns at fractional zoom and HiDPI, check magnified pixel edges,
and preserve the strict default-CRISP map/backdrop seam checks. GAME and EXTRUDE
backdrops are checked for actual minified smoothing and filter-state restoration.

Final validation with actual engine modules and synthetic graphics:

| Engine | Headless camera | Preview UI | Real LÖVE camera |
| --- | ---: | ---: | ---: |
| 0.3.19 | 17,396 | 149 | 721,667 |
| 0.3.22 | 17,396 | 149 | 721,679 |

The separate extrusion suite passes 58,398 GPU checks per engine. These checks
do not substitute for an in-game replay of the reported saves or certify every
scenery family and platform.

## 0.15.0 Full-Scroll, Bounded scenery, and corner blending

Added `mode = "scroll"` (SCROLL/Full-Scroll in the menu). Full's own scale is
`min(vw/w, vh/h)` — limited by whichever axis needs the *most* zoom-out to fit,
leaving the other axis with slack/backdrop margin. Scroll instead uses
`max(vw/w, vh/h)` for its scale (flat) or an equivalent single-axis exact-fit
magnification (Tilt, derived from Full's own projected envelope via the linear
magnification identity already used by Hybrid, not a fresh perspective
re-fit): the axis that had slack in Full becomes locked (now fits exactly,
zero slack, matching Full's own stationary framing on that axis), while the
axis that was Full's own limiting/edge-touching one instead gets genuine room
to scroll with the player. Both axes are always clamped to the area's own
bounds (never revealing void), unlike Hybrid's unconstrained axis, which may
intentionally expose connected/backdrop scenery. `zoomLevel()` returns `1`
immediately for `"scroll"` (no exposed zoom setting; the scale is fully
determined by this fit, not a user zoom multiplied onto it). An earlier version
of this mode reused Hybrid's own limiting-axis choice unmodified with zoom
fixed at 1, which is a no-op (identical to Full, since locking the
already-exactly-fit axis while leaving the already-oversized axis technically
"free" produces no visible scrolling); it locked precisely the wrong axis.

CONNECTIONS and MAP SHADE were gated by a single `sceneryMode` boolean
(`mode == "full" or "hybrid" or "partial"`, now also `"scroll"`); the actual
connected-capture, coverage, and shading code was already mode-agnostic (driven
only by the current `frame`/`terrain` locals), so extending Bounded required
no changes beyond that gate. Bounded's own camera stays strictly contained
within its map (`G.project`'s `partial` branch clamps `x`/`y` to `bounds`), so
connected/shaded scenery only becomes visible when MAX ZOOM caps the scale
below what's needed to contain the viewport (the existing undersized-room
case) — ordinary open-area walking in Bounded still never exposes anything
past the map edge, matching the setting's "polish, not reframing" intent.

`scenery_patterns.lua`'s diagonal corner cells (`B.regions`' four two-axis
regions) previously resolved through a single tile clamped to the map's exact
corner cell, repeated across the whole diagonal region. `classify` now derives
the corner independently from three sources per cell: the horizontal edge's
tile (sampled from the corner-adjacent column, `strip(x, w)`-mapped for
periodicity), the vertical edge's tile (same, by row), and the literal corner
tile, each resolved through the same per-family rules (`classifySource`) used
for straight strips. `mergeCorner` picks whichever edge is periodically closer
to that diagonal cell (`cornerDistance`, matching each axis's repeat period so
the blend never desyncs from the repeated strip) **only when both edges
resolved to a recognized replacement**; if only one edge matched a family (the
overwhelmingly common real-map case: a wall, fence, or building corner meeting
ordinary unrecognized terrain), that one match is always used regardless of
distance. An earlier version of this distance tie-break applied even when only
one side was present, silently discarding that valid match whenever the
unmatched side happened to be geometrically closer — this made most of the
corner fixes reported in testing ineffective in practice, since a corner needs
both sides recognized (rare) for the bug not to trigger. Fixed and covered by
two new targeted regressions (row-only and column-only recognized corners,
checked to still fail without the fix). Authored wall corner pieces
(`cliffCorner`) keep their own artwork at the immediate tie cell instead of
being overridden.

Added a `fences` MID set (`0D6/0D7/0E6-0E9/0EC-0EE`, `315-317/31D/320/325-327`)
that self-repeats, checked before building/tree fallback so fence strips are
never overwritten by adjacent scenery rules winning the corner merge.

Generalized the single Viridian-Forest-specific 3x2 border case into a small
`motifDefs` list matched by exact authored signature (as before, never by
address or secondary MID alone): the existing Forest signature, a reversed
Pattern Bush signature (`290/291/292/298/299/29A`, Six Island), and a Safari
Zone bush signature (`2F5/2F6/2F7/2FD/2FE/2FF`). Each still requires every
output MID to exist in the current atlas via `Native.hasMid` before enabling.

New regression coverage: reversed Pattern Bush and Safari 3x2 continuation,
fence self-repeat, authored cliff-corner preservation, periodic diagonal
cliff-axis blending, mixed cliff/tree diagonal resolution, the corner-merge
discard fix (two cases confirmed to fail without it), and flat/Tilt Scroll's
corrected axis assignment, scale, bounds, and genuine-movement checks
(confirmed to fail against the original, wrong-axis implementation).

Final validation: CPU `tests/scenery_patterns_test.lua` 1,942/1,942. Real LÖVE
GPU on 0.3.19: `tests/scenery_patterns_test.lua` 495,526/495,526 standalone,
full `tests/camera_test.lua` suite 770,216/770,216 (includes the separate
58,398 extrusion checks), headless camera 18,447/18,447 on both engines. As
with prior passes, these are synthetic regression checks, not a replay of the
specific reported saves; map/MID identification for most reported screenshots
was reduced to confidently-verified MID families and fixed structurally rather
than confirmed against one exact map (Safari Zone and Six Island were
confidently identified by exact border signature).
