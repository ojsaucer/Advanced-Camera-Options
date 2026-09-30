# Advanced Camera Options

**See FireRed, LeafGreen and Emerald from a different perspective.**

Choose a stationary whole-area view, a one-axis scrolling view, a zoomable
Hybrid view, a camera that follows you within map edges, or the game's normal
camera.

**[Download the latest release](https://github.com/ojsaucer/Advanced-Camera-Options/releases/latest)**
 · [Installation](#installation) · [Launcher updates](#launcher-updates) · [Settings](#settings)
 · [Known limitations](#known-limitations) · [What's new](CHANGELOG.md)

## Main features

- **Full Static:** see the entire area at once while your character moves around
  inside a stationary scene.
- **Full-Scroll:** zoom in until the area's shorter dimension exactly fills the
  screen and stays stationary, while the camera follows your character along
  the other, longer dimension, stopping at its edges. A tie keeps the camera
  stationary like Full Static.
- **Hybrid:** zoom into Full's framing and follow your character, constraining
  only the axis that touches the screen edges in Full. The other axis can show
  extruded or connected scenery.
- **Bounded:** follow your character until the camera reaches the area's edges.
  See the Tilt corner limitation below.
- **Normal:** switch back to the game's usual camera whenever you want.
- **Tilt:** keep the game's tilted perspective, with upright sprites that get
  smaller in the distance and larger near the camera.
- **Adjustable zoom:** 5-200% in 5% steps for Bounded mode. Keep a consistent
  zoom between areas or make it relative to each area's size.
- **Comfortable interiors:** optionally cap Bounded zoom so small rooms do not
  become excessively enlarged. Leftover space uses your selected backdrop.
- **Connected scenery:** optionally show directly connected maps around Full,
  Full-Scroll, Hybrid, or Bounded views without changing current-area framing
  or repositioning the camera toward areas you haven't entered.
- **Clearer zoomed-out views:** optional Screen Resolution preserves more detail
  without making dialogue or menus larger. Keep crisp pixels or enable Smooth
  filtering to reduce aliasing when zoomed out.
- **Matching backgrounds:** optionally use the game's Void Fill choice around
  the area, following Tilt and forest shade, or choose **Extrude** to repeat
  complete recognized trees and extend water naturally, with single-tile
  repetition for unrecognized scenery. Recognized trees are completed using
  each game's own artwork on both FireRed/LeafGreen and Emerald; other
  content-aware completion (rocks, water, fences, walls) is currently
  FireRed/LeafGreen only.
- **Clear map boundaries:** darken connected-map terrain and backgrounds uniformly or gradually
  with distance, without dimming your current map or characters.
- **Area transitions:** choose fade, a slide toward the connected area you enter,
  or no added transition.
- **Smoother battle entry:** keep the current camera framing while the game's
  battle animation plays.
- **Built-in help:** highlight any mod setting and press **Select**.
- **Settings preview:** press **Start** in the mod's in-game options to preview
  the paused scene, then **B** to return.

The project is called **Advanced Camera Options** on GitHub. It appears as
**Static Camera** in the game; that name and its mod ID are kept so existing
installations retain their settings.

## Supported games and versions

| | Support |
| --- | --- |
| Games | FireRed, LeafGreen and Emerald |
| Tested Gen1Recomp versions | **0.3.19, 0.3.22 and 0.3.33** |
| Other stable 0.3.x versions, starting at 0.3.19 | Optional, untested: enable **UNTESTED ENGINE -> TRY** |
| Gen 1 and Gen 2 | Planned, not available yet |
| Ruby and Sapphire | Not supported |

Untested versions are disabled by default. TRY is not a promise of compatibility.
Development builds, engine versions outside the supported 0.3.x family, and
different mod API versions are not supported.

This mod needs the launcher's **engine_internals** permission to change camera
rendering. It does not modify engine files, collision or player coordinates.
Because it uses internal rendering features, future game updates may still
require a mod update.

## Installation

No compiling or programming is needed.

1. Download **`static_camera-<version>.zip`** from the
   [latest release](https://github.com/ojsaucer/Advanced-Camera-Options/releases/latest).
   Use the mod ZIP under **Assets**, not GitHub's **Source code** downloads.
2. In the Gen1Recomp launcher, open **MODS -> Import mod .zip** and choose the ZIP.
3. Enable **Static Camera** for FireRed, LeafGreen or Emerald.
   Allow its declared permission if prompted.
4. Start the game once to register the settings, then open the mod's options.
   Return to the launcher if its settings list needs refreshing.

Already have an older version installed? See the one-time upgrade below:
**Import mod .zip does not replace an existing installation with the same ID.**

### Manual installation or one-time upgrade from 0.10.0 and earlier

Older versions did not include the repository information needed to find updates.
Install **0.10.1 or newer** once manually; future updates can use the launcher.

Fully close Gen1Recomp, then extract the runtime ZIP into **`mods\static_camera`**
inside the game's user-data folder, replacing the old mod files.
**`manifest.json`** must be directly inside **`static_camera`**, not in a nested
folder. Reopen the launcher and verify enablement. The mod ID is unchanged.

On Windows, the usual folder is:

```text
%APPDATA%\pokemon-love2d\mods\static_camera
```

On other devices, use the equivalent folder inside Gen1Recomp's user-data
directory. Tested engine versions do not imply testing on every device.
The same Lua mod ZIP is used; it contains no ROMs or game assets.

## Launcher updates

Starting with **0.10.1**, the mod identifies its GitHub repository to the launcher.
No separate updater or extra network permission is needed.

1. Open **MODS -> Check for updates**.
2. When an update is available, choose the mod's **Update** action and confirm.
3. Use **Versions** to select or reinstall a published version.

Opening MODS alone does not check for releases. If a new release is missing,
use the mod's manual update recheck to refresh the list. Updates need internet
access. Builds listed only under GitHub Actions are not launcher releases.

**Gen1Recomp 0.3.22 installer issue:** repeated installation or replacement in
the same launcher session can fail with **"could not write ... no such directory"**.
Fully exit and reopen Gen1Recomp before retrying. A failed replacement may remove
the previous mod files, so keep the ZIP for manual recovery using the steps above.
This is an engine installer issue, not something the mod can fix before it loads.

## Settings

The 18 options start with camera mode, then **scenery (Full/Full-Scroll/Hybrid/Bounded)**,
**Hybrid zoom**, **Bounded-specific**, and **shared** settings. Mode-specific options stay
visible for configuration but only affect their named camera mode. Most changes take
effect immediately.

| Setting | What it does |
| --- | --- |
| **CAMERA MODE** | **FULL** shows the whole area; **SCROLL** (Full-Scroll) zooms in until the area's shorter dimension exactly fills the screen and scrolls the longer one; **HYBRID** zooms into Full and follows with one-axis constraints; **BOUNDED** follows within all edges; **NORMAL** restores the game's camera. |
| **CONNECTIONS** | **ON** shows directly connected terrain, without neighboring NPCs or changes to framing. In Bounded this only fills in scenery the moving camera can already see past the area's edge; it never repositions the camera toward areas you haven't entered. **OFF** by default. |
| **MAP SHADE** | **OFF**, **UNIFORM**, or **GRADIENT**. Darkens neighboring terrain and GAME/EXTRUDE backgrounds outside the current map. Works with connections off too. |
| **SHADE STRENGTH %** | **0-100%** darkness; default **60%**. Higher makes the surrounding terrain and background darker. |
| **SHADE DISTANCE** | **1-32 tiles**; default **8**. Distance from the active map's edge where a gradient reaches full strength. |
| **HYBRID ZOOM %** | **100-200%** of Full's fit, in **5% steps**; default **100%**. Only affects Hybrid. |
| **BOUNDED: BASIS** | **NORMAL** keeps zoom consistent between areas. **AREA FIT** bases it on the whole-area view instead. |
| **BOUNDED ZOOM %** | **5-200%**, in **5% steps**. Higher means closer. Only affects Bounded mode. |
| **MAX ZOOM** | **OFF**, or **5-200%** in 5% steps. Caps Bounded zoom at a percentage of normal engine scale, regardless of Zoom Basis. Small rooms use backdrop margins when needed. |
| **AREA FRAMING** | **SCENE** includes the whole authored map. **TERRAIN** crops around terrain connected to your entry point. |
| **CROP PADDING** | Adds **0-4 map tiles** around a terrain crop. |
| **WORLD RESOLUTION** | **RETRO** keeps the original pixelated look. **SCREEN** keeps more detail when zooming out. |
| **SCREEN FILTER** | **CRISP** (default) keeps hard pixel edges. **SMOOTH** reduces minification aliasing in SCREEN terrain and backgrounds; enlarged pixels stay crisp. Does not affect Retro or Normal mode. |
| **VOID BACKDROP** | **BLACK** leaves black margins. **GAME** follows the game's Void Fill selection. **EXTRUDE** extends recognized outdoor scenery intelligently, with single-tile-strip fallback for anything unrecognized; indoors and underground stay black. |
| **AREA TRANSITION** | **NONE**, **FADE** or **SLIDE**. Slide direction follows the map connection automatically. |
| **TRANSITION MS** | Transition duration, **50-2000 milliseconds**. Higher means slower. |
| **UNTESTED ENGINE** | **OFF** by default. **TRY** allows attempting an untested stable engine version in the supported range. |

**Tilt and the GAME backdrop's underlying Void Fill choice are game settings.**
EXTRUDE uses the map's own tiles independently of that game setting.

For a closer moving view, try **BOUNDED**, **BOUNDED: BASIS: NORMAL** and
**WORLD RESOLUTION: SCREEN**, then adjust zoom to taste. For a stationary
whole-area view, choose **FULL**. For a corridor-like area that's much longer
in one direction, choose **SCROLL** to zoom in until the shorter side exactly
fits and scroll along the longer one, without any extra zoom setting.

For a closer view with decorative edges, choose **HYBRID**, **VOID BACKDROP:
EXTRUDE**, then increase **HYBRID ZOOM %**. Hybrid follows the player on both
axes, but clamps only the axis whose opposite edges touch the viewport in Full.
If both axes fit exactly, both are constrained. At 100%, the constrained axis
stays centered; the other axis can still follow. Bounded's zoom controls and
MAX ZOOM do not affect Hybrid. Connections and Map Shade work in Full,
Full-Scroll, Hybrid and Bounded alike.

If interiors look too large, try **MAX ZOOM: 100%**. **OFF** preserves the old
strict map-only framing. The cap also overrides a higher Bounded Zoom setting.

### Extruded edges and map boundaries

Choose **VOID BACKDROP: EXTRUDE** for content-aware outdoor backgrounds:

- Recognized trees are completed at the edge, then repeated as whole patterns.
- Recognized water rocks are replaced with the game's ocean-water pattern in
  the extension; the rocks on the real map stay untouched.
- Recognized water-facing shorelines finish once, then extend as open water,
  rather than repeating coastlines indefinitely.
- Viridian Forest, Six Island's Pattern Bush, and the Safari Zone each use
  their own three-tile-wide tree/bush pattern rather than the smaller
  outdoor pattern.
- Recognized building and gatehouse pieces extend as trees instead of repeated
  roof fragments. Straight rock walls continue along their direction; corner
  pieces straighten to match the map edge being crossed. Other cliff extensions
  use solid mountaintop terrain.
- Recognized fences and guardrail posts repeat as themselves instead of being
  overwritten by neighboring tree or cliff rules.
- Diagonal map corners blend whichever of the two meeting edges is closer,
  instead of repeating a single corner tile.
- Walkable ground (plain grass, tall grass, paths) is never repeated into the
  backdrop, since that would look like more walkable area exists past the
  map's actual edge. The nearest non-walkable boundary tile along that same
  edge is substituted instead.
- On Emerald, recognized General-tileset trees complete the same way, using
  Emerald's own artwork; other scenery types are not yet recognized there.

Recognition currently covers verified families in FireRed/LeafGreen's **General**
tileset, Viridian Forest's matching tree-border set, and Emerald's own General
tree border, not custom tilesets. Unrecognized scenery repeats the nearest
non-walkable tile along that boundary edge, or its own boundary tile if that
edge has no non-walkable tile at all; corners do the same search in both
directions. Tiles keep their orientation. This is decorative, not walkable
terrain, and works best on maps with suitable edge scenery. The source is the
authored map edge, not the Terrain crop. Connected maps still draw over the
background; this never edits real terrain. Indoors and underground, EXTRUDE
automatically uses black so walls, decorations and empty map tiles do not
repeat around the room.

For visible map boundaries, choose **MAP SHADE**. Uniform shading provides
a clear brightness change; Gradient starts clear at your map's boundary and
darkens outward, across both connected terrain and GAME/EXTRUDE backgrounds.
The effect follows Tilt, leaves characters and menus unchanged, and moves to
the new map's boundary when you cross. Connections do not need to be enabled.
Connected scenery contains terrain only: neighboring NPC sprites are not rendered.

Older H-scroll and V-scroll preferences now use Slide; the old reverse-animation
setting is ignored. Changes without a reliable connection direction switch
immediately rather than sliding in an arbitrary direction. Door fades remain
game-controlled.

### Help for each option

Highlight a setting and press your configured **Select** button.
Use the direction buttons to turn pages, then **B** or **Select** to close.
Opening help does not change the setting. Help also covers **Reset Defaults**.

### Preview without leaving options

In Static Camera's **in-game** options, press **Start** to open the preview.
It redraws the scene using your current settings while keeping gameplay paused.
Press **B** to return to the same setting and menu position.

Preview is available for Full and Bounded cameras after entering a map, not
from the launcher's settings or during protected scenes. It preserves the
camera's aspect ratio inside the menu display; Screen Resolution sharpness is
only approximate in this lower-resolution preview.

## Known limitations

- **Bounded + Tilt can let the player leave the visible screen at either bottom
  corner.** This is an existing consequence of keeping the tilted camera strictly
  inside the area's boundaries. That behavior is intentionally unchanged.
- **With MAX ZOOM off, small or narrow areas enforce a minimum zoom.** A low percentage remains
  selectable, but the camera may need a closer view to avoid showing outside
  the area. Enabling MAX ZOOM permits backdrop margins instead. Full mode uses
  its own automatic fit.
- **A whole area and the screen may have different shapes.** Full mode keeps
  the area visible and centered; leftover space uses the selected backdrop.
  Void Fill is decoration, not additional playable terrain.
- **Terrain cropping is approximate.** It does not account for story progress,
  HM availability or NPC blockers. Choose SCENE if a crop is unsuitable.
- **Void Fill does not repeat every effect.** Forest shade is supported; local
  fog, rain and cave-light effects are not extended onto the repeating background.
  Black tiles inside the map stay black, and space above a visible Tilt horizon
  stays black.
- **EXTRUDE's content-aware completion covers only recognized families.** Trees
  are recognized on both FireRed/LeafGreen and Emerald, each using that game's
  own artwork. Other scenery (rocks, water, fences, walls) is currently
  FireRed/LeafGreen only; unrecognized scenery always uses plain edge-tile
  repetition rather than guessing at unrelated replacement tiles.
- **Special cameras and cutscenes use the original renderer.** Door and scripted
  fades remain game-controlled rather than playing an extra mod transition.
- **Battle animations temporarily use native pixel resolution.** The camera
  framing stays put, but SCREEN can look more pixelated while the original battle
  effect runs. Exceptional effects explicitly drawn over UI retain the engine's
  protected presentation.
- **SCREEN uses more graphics memory.** Unsupported or memory-limited cases can
  fall back to RETRO. Engine mirrored/capture previews remain low-resolution.
  Optional connected scenery is omitted if its larger image cannot fit, rather
  than changing the primary camera or downgrading its resolution.
- Other camera-replacement mods are not supported together. Full playthroughs,
  every map/effect and every device have not been certified.

## About this project

**AI development disclosure:** This mod was built primarily using **Astra**,
with human direction and in-game feedback. It has automated regression tests,
but AI assistance and passing tests do not guarantee bug-free gameplay.

This is an unofficial community mod, not an official Gen1Recomp release.

Found a problem? [Open an issue](https://github.com/ojsaucer/Advanced-Camera-Options/issues)
with your engine/mod versions, area, settings and steps to reproduce it.
Please do not upload ROMs, game assets, saves or personal information.

For implementation, build and test details, see the
[technical reference](docs/TECHNICAL.md). For bug-report and release-note
guidelines, see [Contributing](CONTRIBUTING.md).
