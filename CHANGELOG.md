# Changelog

## [0.10.0]

### Changed
- FULL/BOUNDED Tilt sprites now scale by the perspective factor at their feet,
  preserving upright proportions, foot anchoring and sprite-local transforms.
  Applies to player/NPC billboards and supported actor-effect callbacks.
- Full fitting accounts for depth-scaled sprite envelopes. AREA FIT zoom uses
  the updated fit; strict Bounded clamps are not relaxed.
- Scoped billboard handoff validation and restoration prevent graphics hooks
  leaking into terrain, UI, later actors or later frames.

### Documented
- The player can leave the visible screen near either bottom corner in strict
  Bounded Tilt. The requested behavior is preserved, not fixed or relaxed.
- This release also publishes the compatibility and shade improvements from
  the previously local 0.9.0 and 0.9.1 builds.

### Validation
- 6421/6421 headless assertions passed on each tested engine.
- GPU: 12992/12992 assertions on 0.3.19; 13004/13004 on 0.3.22.
- Near/far NPC pixel sizes, foot anchors, Full/Bounded, both resolutions and
  HiDPI, actor-local transforms and billboard failure cleanup are covered.
- Tests use actual engine modules with synthetic assets. Imported-map gameplay
  and actual-device performance still need testing.

## [0.9.1]

### Fixed
- GAME Void Fill now receives the engine's uniform forest-shade tint before
  projection, matching the map without double-tinting terrain or affecting UI.
- Repaint and shade once per frame so dimming does not accumulate. Weather
  suspension and shade removal follow native behavior; transitions retain the
  outgoing area's captured tint.
- Shade capability is optional and independent of the camera/backdrop checks.
  Spatial fog, rain and local effects are not tiled onto the repeat texture.

### Validation
- Reproduced 54 failing shade GPU checks before applying the fix.
- 6420/6420 headless assertions on each tested engine; GPU totals:
  12648/12648 on 0.3.19 and 12660/12660 on 0.3.22.

## [0.9.0]

### Added
- Central compatibility policy and capability checks instead of three separate
  exact-version restrictions. Regression-tested engines: 0.3.19 and 0.3.22.
- UNTESTED ENGINE: OFF by default, TRY for explicit experimental opt-in on other
  stable 0.3.x engines from 0.3.19. Live opt-out restores normal behavior.
- Independent fallbacks for unavailable SCREEN, Tilt projection, terrain crop,
  Void Fill and settings-help capabilities, with diagnostic warnings.
- Policy, loader, missing-module/method, optional-fallback and lifecycle tests.

### Fixed
- Isolate 0.3.22 native cell-list/pool scratch state alongside camera tile caches.
- Keep the original draw path, including normal Tilt, on subsequent frames
  after a camera fault. The original error still propagates after cleanup.
- Clear detached attachment tracking so opt-in can reattach after draw-time opt-out.

### Validation
- 6417/6417 headless assertions passed separately on 0.3.19 and 0.3.22.
- Real LOVE graphics: 12337/12337 passed on 0.3.19; 12349/12349 on 0.3.22,
  including new collected-effect callback projection checks.
- Untested-version simulation validates policy only. Actual-device gameplay
  and performance on imported maps still require testing.

## [0.8.0]

### Fixed
- GAME Void Backdrop now shares the map's native Tilt perspective, world phase,
  depth scaling and centering instead of drawing a flat screen-plane pattern.
- Clip repeated ground below the horizon in tiny high-angle rooms, avoiding
  singular coordinates or upside-down terrain. Above-horizon space stays black.
- Restore the borrowed native mesh texture and previous shader on draw errors.

### Added
- Inverse-projection pixel regressions at 15/35/50 degrees across Retro, SCREEN,
  HiDPI and both supported games, plus tiny-room horizon checks.
- Versioned PowerShell ZIP/checksum packaging, a VS Code build task and GitHub
  Actions packaging artifacts. No engine modules or game assets are bundled.

### Validation
- 6192/6192 headless and 12112/12112 real LOVE graphics assertions passed.
- All 18 regression cases that failed with the flat backdrop now pass.
- Actual-device gameplay/performance testing is still required.

## [0.7.0]

### Added
- Void Backdrop: BLACK (default) or GAME, with detailed Select-help.
- GAME decorates unused margins, including Tilt margins, using the engine's
  Extras Void Fill selection and its compatible-tileset/MAP fallback rules.
- Integer-rasterized repeat patterns preserve atlas animation without revealing
  neighboring maps, replacing authored black tiles, or expanding camera bounds.
- Tests for all fill modes, tileset/metatile fallback, repeated border phase,
  UI/black-tile preservation, both resolutions, HiDPI, Tilt corners, transitions
  and optional-buffer allocation failure.

## [0.6.0]

### Added
- Genuine engine-style Tilt in Full and Bounded modes: perspective ground,
  upright sprites, whole-area fitting and perspective-aware boundary clamps.
- Tilt geometry and GPU regressions for projected corners, all four bounded
  edges, sprite feet/height, DPI, transitions and changing angles.
- Compensation for the audited mirrored world-override presentation path.
- Content-aware, grow-only upright clearance avoids oversized margins in
  small tilted rooms while allowing larger map actors.
- SCREEN buffer/budget failures retry RETRO while retaining Tilt and camera
  bounds; flat rendering does not reserve an unused upright buffer.

### Fixed
- Moving-camera tile seams caused by direct fractional rasterization of tightly
  packed atlas cells. Assemble the whole field at integer world-pixel coordinates,
  then scale its completed image; preserve sharp Screen Resolution output.
- Added guard pixels and correct Flash/camera rebasing, cache sizing and
  lifecycle cleanup for the reusable world-space staging buffer.

### Validation
- Reproduced neighbor-color leakage in 36 of 80 moving Bounded frames before
  the fix, versus zero in vanilla. The corrected path passed 1,440 moving GPU
  frames across both games, including packed ground and transparent overhead
  atlases, Full/Bounded/Normal, both resolution modes and 2x DPI.
- Existing detail-retention, zoom, bounds, transitions and settings-help tests
  remain covered; new staging-buffer failure tests preserve renderer state.

## [0.5.0]

### Added
- Per-setting detailed Select-help, scoped to Static Camera's options.
- Clear, non-truncated labels and values, grouped by camera/zoom, framing,
  rendering quality, then transitions.

### Changed
- Bounded zoom now ranges from 5 to 200% in 5% steps. Lower percentages zoom
  out; higher zoom in. Area boundaries still impose a minimum effective zoom.
- Existing out-of-range zoom values are clamped and normalized when opening
  this mod's options. The default remains 200%.
- Menu aliases: FULL/BOUNDED/NORMAL camera; NORMAL/AREA FIT zoom basis;
  SCENE/TERRAIN framing; RETRO/SCREEN rendering.
- Scroll Direction uses explicit NORMAL/REVERSE choices, preserving saved
  boolean direction values.

### Fixed
- Avoid layering another camera animation over the engine's door/warp fade.
  Camera positioning continues under the existing cover; ordinary un-faded
  area crossings still use the configured mod transition.

## [0.4.0]

### Added
- Partial Zoom Style: Consistent (new default) or Area Relative (old behavior).
- Consistent zoom uses the normal engine scale rather than each area's Full
  fit, keeping character/tile size steady across maps that contain the viewport.
- 100% Partial zoom, matching the normal engine scale in Consistent mode.
- Geometry and final-output GPU tests for scale across map sizes, resolution
  modes, DPI, rounded viewport dimensions and normal/survey engine zoom.

### Changed
- Partial zoom now accepts 100-800%; the default remains 200% and existing saved
  percentages are preserved. Choose Area Relative to
  preserve the previous percentage interpretation.
- Small/narrow areas still increase zoom as needed to hide outside space.
  Full Static, framing choices and transitions retain their existing behavior.
- Screen Resolution uses the engine's exact physical world scale for Consistent
  zoom, not an approximation from its even-rounded logical viewport.

## [0.3.0]

### Added
- World Resolution setting: Retro (default) or Screen Resolution.
- Direct physical-pixel world rendering through the installed 0.3.19
  renderer's native world override, preserving engine UI scale and world fades.
- HiDPI/viewport resizing, explicit Retro fallback for unsupported presentation
  paths, GPU limits or allocation failure, and scoped override cleanup.
- Final-compositor GPU tests proving fine-detail retention rather than merely
  enlarging a low-resolution image, plus UI, HiDPI, resize, native transition,
  fallback, ownership and error-cleanup regression coverage.

### Changed
- Presentation-buffer resizes retain the cached entry crop.
- Kept the working 0.2.0 package; no engine files or installed mods are changed.

### Limitations
- Higher resolution increases GPU memory/work and does not add sprite detail.
- Engine mirror/capture previews retain their original low resolution.
- The existing exact engine 0.3.19 and Gen 3 compatibility limits still apply.

## [0.2.0] - 2026-09-26

### Changed
- Replace the fork-only hook with an explicitly authorized, version-audited
  engine-internals adapter for the installed 0.3.19 payload.
- Separate engine-independent geometry from renderer integration.
- Preserve Normal mode and protected engine presentations; temporarily bypass
  Tilt for mod-owned flat views without changing saved preferences.

### Added
- Toggleable Full Scene / Reachable-Area Crop framing, independent of mode.
- Crop padding, bounded terrain traversal and cached stationary crop bounds.
- Clipped canvases and scoped exclusion of adjacent-map tiles and actors.
- Outgoing/incoming fade through black, horizontal and vertical scroll,
  duration and reverse-scroll settings.
- Renderer/collision/loader tests using the installed engine, plus real GPU
  pixel tests with original synthetic fixtures.

### Limitations
- Terrain cropping does not model progression, HM availability or NPC blockers.
- Exceptional movement beyond a cached crop expands it to preserve visibility.
- Simulation timing, scripted fades and protected presentations remain owned
  by the engine. Imported-map gameplay/performance testing is still required.

## Compatibility audit - 2026-09-25

- Marked 0.1.0 and its ZIP as unsuitable for upstream builds; no replacement
  release is available.
- Verified upstream dev at `e7ce2a3a7195dc4f5f7d6177cddc736afcd0ff66`, the
  official wiki, and the installed 0.3.19 update payload.
- Confirmed both an incorrect exact development-version pin and a fork-only
  `camera.field` hook absent from upstream and the installed update.
- Corrected the earlier test claims: 116 assertions passed on the local fork,
  not against upstream compatibility.
- Documented the user's public-API-only decision and the missing Gen 3 camera
  contract. No engine-internals adapter or version-range-only workaround added.
- Updated both agent profiles to distinguish upstream documentation, installed
  release capabilities, and local-fork changes.

## [0.1.0] - 2026-09-25

Fork-only prototype; not compatible with audited upstream builds.

### Added
- FireRed/LeafGreen whole-layout Full Static and closer Partial / Bounded modes.
- Normal-mode passthrough and preservation of the engine's special shop camera.
- Relative partial zoom, incoming-only fade/slide and duration settings.
- Layout isolation, guarded geometry, and warnings for invalid settings/context.
- Lua headless-loader and camera regression tests.

### Limitations
- Targets the existing local `camera.field` implementation, not a stable documented contract.
- Playable-interior cropping, complete rendering clips, prepared two-area transitions,
  vertical scrolling, and Gen 1/2 support are deferred.
