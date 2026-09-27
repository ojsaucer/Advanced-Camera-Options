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
