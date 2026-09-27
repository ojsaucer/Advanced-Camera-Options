# Contributing

Bug reports and clear in-game feedback are welcome. Please include:

- Gen1Recomp and mod versions.
- FireRed or LeafGreen, the area, and your camera settings.
- What happened, what you expected, and how to reproduce it.
- A screenshot or relevant error message if available.

Do not upload ROMs, imported game assets, saves, credentials or personal data.

## Documentation and release notes

Keep the project welcoming to players who do not write code.

- Lead the README with features, installation and common questions.
- Keep the Astra development disclosure visible and accurate.
- Write changelog and GitHub release bullets around what players will notice:
  what was added, what was fixed, and any important compatibility changes.
- Prefer "Fixed bright backgrounds in shaded areas" over descriptions of
  canvases, shaders, transforms or internal function names.
- Include technical details in release notes only when they are the main
  subject of the change. Put implementation notes and test details in
  [the technical reference](docs/TECHNICAL.md).
- Do not claim broader device, engine or gameplay support than was tested.

## Code and releases

This is a Lua mod. Use the existing PowerShell build script for packaging and
the existing Lua tests for runtime changes. See the
[technical reference](docs/TECHNICAL.md) for setup.

Keep the mod ID `static_camera` stable so existing installations and saved
options remain associated with the same mod. Publish a new version for package
changes rather than silently replacing an old release asset.
