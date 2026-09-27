# Changelog

What's new for players. For implementation and testing details, see the
[technical reference](docs/TECHNICAL.md).

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
