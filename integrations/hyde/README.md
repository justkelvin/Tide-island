# HyDE integration preset

This directory records the Tide Island and Waybar settings used to run Tide
embedded in a HyDE/Hyprland Waybar layout. It is intentionally not installed
by Tide Island's build or installer — copy the files in manually (or via the
commands below) after building/installing Tide Island itself.

- `tide-island/userconfig.json` is the Tide Island runtime preset.
- `waybar/layouts/tide-island.jsonc` is the matching HyDE Waybar layout.
- `waybar/styles/tide-island.css` selects HyDE's standard pill styling.
- `waybar/modules/tide-island.jsonc` retains the optional center-spacer module
  from the initial integration; the current layout does not use it.

## How the QML integration works

- `DynamicIslandWindow.qml` watches `~/.config/waybar/theme.css` for
  `@define-color main-bg ...` and tints Tide's capsule background with that
  color, blended with the normal `islandBackgroundOpacity` setting. The preset
  config sets `islandBackgroundOpacity` to `100` so the capsule renders fully
  opaque and matches Waybar's bar color exactly (set it lower if you want the
  capsule to be translucent instead).
- Tide's top-level window sets `exclusionMode: ExclusionMode.Ignore` and
  `WlrLayershell.layer: WlrLayer.Overlay` with `WlrLayershell.namespace:
  "tide-island"`, so it renders as a separate overlay surface that ignores
  Waybar's reserved space instead of pushing Waybar down or being pushed below
  it.
  - Important: do not also bind the window's `exclusiveZone` property.
    Quickshell's `exclusiveZone` setter forces `exclusionMode` back to
    `Normal` as a side effect, which silently breaks `Ignore` the next time
    that binding re-evaluates (e.g. during auto-hide animations). Leave
    `exclusiveZone` unset whenever `exclusionMode` is `Ignore`.
- Both Tide and Waybar share the existing 10-pixel Waybar layout without
  changing its configured height; Tide overlays on top of it rather than
  growing it.

The layout leaves the center module list empty because Tide is a separate
layer-shell surface rather than an in-process Waybar module. The left
workspace group and the right tray/battery group remain native Waybar
modules.

## Applying the preset

Back up your current configuration first:

```bash
cp -a ~/.config/tide-island ~/.config/tide-island.backup
cp -a ~/.config/waybar ~/.config/waybar.backup
```

Install the preset files:

```bash
install -Dm644 integrations/hyde/tide-island/userconfig.json \
  ~/.config/tide-island/userconfig.json
install -Dm644 integrations/hyde/waybar/layouts/tide-island.jsonc \
  ~/.config/waybar/layouts/tide-island.jsonc
install -Dm644 integrations/hyde/waybar/styles/tide-island.css \
  ~/.config/waybar/styles/tide-island.css
install -Dm644 integrations/hyde/waybar/modules/tide-island.jsonc \
  ~/.config/waybar/modules/tide-island.jsonc
```

Select the layout through HyDE and restart Tide:

```bash
hyde-shell waybar --set tide-island
systemctl --user restart tide-island.service
```

## Notifications and Dunst

Tide observes desktop notification calls and presents them in its pill
(mirroring is always on in this build, matching upstream). Running normal
Dunst presentation at the same time therefore produces duplicate visual
notifications.

Keep Dunst running as the desktop notification service, but pause its visual
presentation while Tide handles the UI:

```bash
dunstctl set-paused true
```

Restore the backed-up Tide and Waybar configuration directories to revert.
