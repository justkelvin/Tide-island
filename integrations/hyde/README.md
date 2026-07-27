# HyDE integration preset

This directory records the Tide Island and Waybar settings used by the HyDE
setup. It is intentionally not installed by Tide Island's build or installer.

- `tide-island/userconfig.json` is the Tide Island runtime preset.
- `waybar/layouts/tide-island.jsonc` is the matching HyDE Waybar layout.
- `waybar/styles/tide-island.css` selects HyDE's standard pill styling.
- `waybar/modules/tide-island.jsonc` retains the optional center-spacer module
  from the initial integration; the current layout does not use it.

The QML integration reads `@main-bg` from
`~/.config/waybar/theme.css`, watches the file for changes, and uses that color
for the resting capsule. Tide ignores Waybar's exclusive zone and renders as an
overlay, so both share the existing 10-pixel Waybar layout without changing its
configured height.

The layout leaves the center module list empty because Tide is a separate
layer-shell surface rather than an in-process Waybar module. The left workspace
group and the right tray/battery group remain native Waybar modules.

Tide's notification server and Dunst should not both be active if duplicate
notifications are undesirable. Pausing Dunst with `dunstctl set-paused true` is
a runtime choice and is not applied by this preset.
