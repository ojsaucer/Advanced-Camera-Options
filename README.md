# Advanced Camera Options

**See FireRed and LeafGreen from a different perspective.**

Choose a stationary view of the whole area, a camera that follows you without
scrolling past map edges, or the game's normal camera.

**[Download the latest release](https://github.com/ojsaucer/Advanced-Camera-Options/releases/latest)**
 · [Installation](#installation) · [Launcher updates](#launcher-updates) · [Settings](#settings)
 · [Known limitations](#known-limitations) · [What's new](CHANGELOG.md)

## Main features

- **Full Static:** see the entire area at once while your character moves around
  inside a stationary scene.
- **Bounded:** follow your character until the camera reaches the area's edges.
  See the Tilt corner limitation below.
- **Normal:** switch back to the game's usual camera whenever you want.
- **Tilt:** keep the game's tilted perspective, with upright sprites that get
  smaller in the distance and larger near the camera.
- **Adjustable zoom:** 5-200% in 5% steps for Bounded mode. Keep a consistent
  zoom between areas or make it relative to each area's size.
- **Clearer zoomed-out views:** optional Screen Resolution preserves more detail
  without making dialogue or menus larger.
- **Matching backgrounds:** optionally use the game's Void Fill choice around
  the area, following Tilt and forest shade.
- **Area transitions:** choose fade, horizontal scroll, vertical scroll or no
  added transition.
- **Built-in help:** highlight any mod setting and press **Select**.

The project is called **Advanced Camera Options** on GitHub. It appears as
**Static Camera** in the game; that name and its mod ID are kept so existing
installations retain their settings.

## Supported games and versions

| | Support |
| --- | --- |
| Games | FireRed and LeafGreen |
| Tested Gen1Recomp versions | **0.3.19 and 0.3.22** |
| Other stable 0.3.x versions, starting at 0.3.19 | Optional, untested: enable **UNTESTED ENGINE -> TRY** |
| Gen 1 and Gen 2 | Planned, not available yet |
| Ruby, Sapphire and Emerald | Not supported |

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
3. Enable **Static Camera** for FireRed or LeafGreen.
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

The options are grouped as camera/zoom, framing, appearance, transitions, then
compatibility. Most changes take effect immediately.

| Setting | What it does |
| --- | --- |
| **CAMERA MODE** | **FULL** shows the whole area; **BOUNDED** follows within its edges; **NORMAL** restores the game's camera. |
| **ZOOM BASIS** | **NORMAL** keeps zoom consistent between areas. **AREA FIT** bases it on the whole-area view instead. |
| **BOUNDED ZOOM %** | **5-200%**, in **5% steps**. Higher means closer. Only affects Bounded mode. |
| **AREA FRAMING** | **SCENE** includes the whole authored map. **TERRAIN** crops around terrain connected to your entry point. |
| **CROP PADDING** | Adds **0-4 map tiles** around a terrain crop. |
| **WORLD RESOLUTION** | **RETRO** keeps the original pixelated look. **SCREEN** keeps more detail when zooming out. |
| **VOID BACKDROP** | **BLACK** leaves black margins. **GAME** follows the game's own Void Fill selection. |
| **AREA TRANSITION** | **NONE**, **FADE**, **H-SCROLL** or **V-SCROLL**. |
| **TRANSITION MS** | Transition duration, **50-2000 milliseconds**. Higher means slower. |
| **SCROLL DIRECTION** | Normal or reversed direction for scroll transitions. |
| **UNTESTED ENGINE** | **OFF** by default. **TRY** allows attempting an untested stable engine version in the supported range. |

**Tilt and the underlying Void Fill choice are game settings**, not extra
sliders added by this mod.

For a closer moving view, try **BOUNDED**, **ZOOM BASIS: NORMAL** and
**WORLD RESOLUTION: SCREEN**, then adjust zoom to taste. For a stationary
whole-area view, choose **FULL**.

### Help for each option

Highlight a setting and press your configured **Select** button.
Use the direction buttons to turn pages, then **B** or **Select** to close.
Opening help does not change the setting. Help also covers **Reset Defaults**.

## Known limitations

- **Bounded + Tilt can let the player leave the visible screen at either bottom
  corner.** This is an existing consequence of keeping the tilted camera strictly
  inside the area's boundaries. That behavior is intentionally unchanged.
- **Small or narrow areas enforce a minimum zoom.** A low percentage remains
  selectable, but the camera may need a closer view to avoid showing outside
  the area. Full mode uses its own automatic fit.
- **A whole area and the screen may have different shapes.** Full mode keeps
  the area visible and centered; leftover space uses the selected backdrop.
  Void Fill is decoration, not additional playable terrain.
- **Terrain cropping is approximate.** It does not account for story progress,
  HM availability or NPC blockers. Choose SCENE if a crop is unsuitable.
- **Void Fill does not repeat every effect.** Forest shade is supported; local
  fog, rain and cave-light effects are not extended onto the repeating background.
  Black tiles inside the map stay black, and space above a visible Tilt horizon
  stays black.
- **Special cameras and cutscenes use the original renderer.** Door and scripted
  fades remain game-controlled rather than playing an extra mod transition.
- **SCREEN uses more graphics memory.** Unsupported or memory-limited cases can
  fall back to RETRO. Engine mirrored/capture previews remain low-resolution.
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
