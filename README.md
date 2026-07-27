# Tide Island for HyDE

A HyDE-focused fork of [Tide Island](https://github.com/enhaoswen/Tide-island),
based on upstream version 1.0.30.

This fork keeps Tide as a standalone Quickshell application while making it
look and behave like the center section of a HyDE Waybar layout. It is not a
Waybar plugin: Tide and Waybar remain separate layer-shell surfaces.

## Why this fork exists

The upstream project is a general Dynamic Island implementation for Hyprland
and niri. This fork is maintained for a HyDE/Hyprland desktop and adds:

- placement over Waybar without increasing Waybar's configured height;
- automatic inheritance of Waybar's `@main-bg` color;
- a reproducible HyDE Waybar layout and Tide configuration preset;
- a resting media view with artwork, clock, and Cava visualization;
- persistent but dimmed artwork and static Cava bars while media is paused;
- rounded artwork in both the resting pill and expanded media player;
- SF Pro Rounded support for the clock;
- stricter MPRIS player selection so stopped browser players do not remain
  visible as stale Chrome media sessions;
- Cava lifecycle control so the visualizer runs only when a visible view needs
  it.

The HyDE preset is stored in [`integrations/hyde`](integrations/hyde/README.md).
Core upstream features and niri support remain in the source, but the custom
integration is designed and tested around HyDE and Hyprland.

## Features

- Clock, media player, timer, synchronized lyrics, and system feedback
- Control center and connectivity controls
- Notification previews and notification history
- Application launcher with favorites and fuzzy search
- Wallpaper picker
- Hyprland workspace overview
- Custom swipe views for battery, volume, brightness, CPU, memory, storage,
  workspace, date, time, and Cava
- Configuration application and Quickshell IPC commands

## Changes since the previously installed 1.0.24

The fork is based on Tide Island 1.0.30. Compared with 1.0.24, upstream added:

- **1.0.25:** a notification centre with up to 50 in-memory history entries,
  individual dismissal, Clear all, and notification-centre IPC commands;
- **1.0.25:** a storage-usage item for custom swipe layouts;
- **1.0.26:** an application launcher, favorites, launcher settings, and
  launcher shortcut support;
- **1.0.27:** a substantially refined configuration app, including an internal
  path picker, plus launcher and wallpaper configuration improvements;
- **1.0.28:** artwork and Cava in the lyrics swipe capsule;
- **1.0.29:** ranked fuzzy application search across names, keywords, desktop
  IDs, categories, and other desktop-entry fields;
- **1.0.30:** previous/next island-view navigation and H/J/K/L workspace
  navigation in the Hyprland overview.

Those are in addition to this fork's HyDE and resting-media changes listed
above.

## Requirements

- HyDE with Hyprland for the intended integration
- Quickshell 0.3.0
- Qt 6.6 or newer
- CMake, a C++17 compiler, Ninja, Git, and pkg-config
- Tide's normal runtime dependencies, including PipeWire/WirePlumber, D-Bus,
  UPower, BlueZ, and `brightnessctl`
- `cava` for the media visualizer
- `SF Pro Rounded` for the configured clock font

Verify the two important optional pieces with:

```bash
quickshell --version
fc-match "SF Pro Rounded"
```

## Build without installing

This is the safe workflow for development and does not change the running Tide
service:

```bash
git clone git@github.com:justkelvin/Tide-island.git
cd Tide-island

cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel
ctest --test-dir build --output-on-failure
```

The main QML files can also be checked with:

```bash
qmllint -I build -I /usr/lib/qt6/qml \
  shell.qml \
  DynamicIslandWindow.qml \
  qml/notifications/TideNotificationService.qml \
  qml/island/NotificationLayer.qml \
  qml/island/NotificationHistory.qml \
  qml/controlcenter/NotificationCenterLayer.qml \
  qml/island/ExpandedPlayerLayer.qml \
  qml/island/IslandMprisController.qml \
  qml/island/IslandSystemState.qml \
  qml/island/RestingMediaLayer.qml \
  qml/island/RoundedArtwork.qml
```

## Install the fork for one user

The recommended fork installation uses `~/.local`. It does not overwrite the
files owned by Arch's `tide-island` package.

```bash
cmake -S . -B build-user \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$HOME/.local"
cmake --build build-user --parallel
ctest --test-dir build-user --output-on-failure
cmake --install build-user
```

This only installs the fork. It does not automatically redirect an existing
system service to it.

When you are ready to activate the fork, first inspect and back up any existing
service override:

```bash
systemctl --user cat tide-island.service
cp -a ~/.config/systemd/user/tide-island.service.d \
  ~/.config/systemd/user/tide-island.service.d.backup
```

Then edit the user override:

```bash
systemctl --user edit tide-island.service
```

Use:

```ini
[Service]
ExecStart=
ExecStart=%h/.local/bin/tide-island
Environment=TIDE_ISLAND_QML_PATH=
```

Apply it:

```bash
systemctl --user daemon-reload
systemctl --user restart tide-island.service
systemctl --user status tide-island.service
```

The empty `TIDE_ISLAND_QML_PATH` assignment is important if an older override
points the launcher at a customized system copy.

### System-wide source installation

The upstream installer can install the current source tree to `/usr`, but this
overwrites package-managed Tide files on Arch and is therefore not the
recommended fork workflow.

Preview what it would do:

```bash
./install.sh --dry-run --skip-deps --skip-quickshell --force
```

Install deliberately:

```bash
./install.sh --skip-deps --skip-quickshell --force
```

Do not use the repository's current `PKGBUILD` for the fork: it downloads the
upstream 1.0.30 archive rather than packaging this working tree.

## Apply the HyDE preset

Back up the current configuration first:

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

Select the layout through HyDE:

```bash
hyde-shell waybar --set tide-island
systemctl --user restart tide-island.service
```

The layout keeps Waybar at height `10`, places grouped workspaces on the left,
places grouped tray and battery modules on the right, and leaves the center
available for Tide's separate overlay surface.

## Notifications and Dunst

Tide is the native `org.freedesktop.Notifications` server. It receives
structured notifications through Quickshell instead of scraping
`dbus-monitor`, so literal newlines, replacement IDs, actions, images,
urgency, close reasons, timeouts, resident notifications, transient
notifications, and inline replies remain available to the UI.

Native mode is controlled by `nativeNotificationsEnabled` in
`~/.config/tide-island/userconfig.json` and defaults to `true` in this fork:

```json
{
  "nativeNotificationsEnabled": true
}
```

Only one process can own the freedesktop notification D-Bus name. Pausing
Dunst is not enough; stop Dunst completely before starting Tide in native
mode:

```bash
systemctl --user stop dunst.service dunst.socket
pkill -x dunst
systemctl --user restart tide-island.service
busctl --user status org.freedesktop.Notifications
```

If HyDE starts Dunst from an `exec-once` entry rather than a user unit, disable
that autostart entry as well. Keep Dunst installed for rollback.

The Silent toggle in Tide's control centre is Tide-owned DND state; it no
longer invokes `swaync-client`. DND suppresses every popup, including critical
popups, while retaining non-transient history. Critical notifications with a
default or zero timeout do not expire automatically. A positive sender timeout
is treated as an explicit expiration request, including for critical
notifications. The freedesktop value `0` means no protocol expiration and
`-1` uses Tide's seven-second default for low/normal notifications.

Popup and notification-centre entries use one global model capped at 50
non-transient entries. History is currently in memory and is cleared on Tide
restart, matching `persistenceSupported: false`. Clear all and individual
dismissal notify live applications before removing entries.

Useful notification checks:

```bash
notify-send --app-name="Tide Test" "Title" "Body text"
notify-send --app-name="Tide Test" "Multiline" $'Line one\nLine two\nLine three'
busctl --user status org.freedesktop.Notifications
journalctl --user -u tide-island.service -f
```

On multiple monitors, Tide routes one popup to the focused output and falls
back to the first Tide window when focus cannot be resolved. The notification
centre remains globally shared.

### Notification rollback

Disable Tide native mode before starting Dunst:

```bash
python - <<'PY'
import json
from pathlib import Path

path = Path.home() / ".config/tide-island/userconfig.json"
data = json.loads(path.read_text()) if path.exists() else {}
data["nativeNotificationsEnabled"] = False
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(json.dumps(data, indent=2) + "\n")
PY
systemctl --user restart tide-island.service
systemctl --user start dunst.service
```

If Dunst is not managed by systemd, start it with `dunst &`. To cut back over
to Tide, stop Dunst, set `nativeNotificationsEnabled` to `true`, and restart
Tide.

Known notification limitations:

- history is intentionally not persisted to disk;
- notification body markup and hyperlinks are advertised as unsupported and
  rendered literally as plain text;
- raw image-data hints depend on Quickshell's bounded image conversion;
- Tide does not currently play notification sounds.

## Updating

```bash
git pull --ff-only
cmake --build build-user --parallel
ctest --test-dir build-user --output-on-failure
cmake --install build-user
systemctl --user restart tide-island.service
```

Review upstream changes before merging them because
`DynamicIslandWindow.qml`, `IslandSystemState.qml`, and the media layers contain
fork-specific integration code.

## Useful commands

```bash
systemctl --user restart tide-island.service
systemctl --user stop tide-island.service
journalctl --user -u tide-island.service -f

quickshell ipc call tide toggleNotificationCenter
quickshell ipc call tide toggleApplicationLauncher
quickshell ipc call tide swipeLeft
quickshell ipc call tide swipeRight
```

## Rollback

To return to the previous service configuration, move the fork override aside,
restore the backed-up drop-in, reload systemd, and restart Tide:

```bash
mv ~/.config/systemd/user/tide-island.service.d \
  ~/.config/systemd/user/tide-island.service.d.fork
cp -a ~/.config/systemd/user/tide-island.service.d.backup \
  ~/.config/systemd/user/tide-island.service.d
systemctl --user daemon-reload
systemctl --user restart tide-island.service
```

Restore the backed-up Tide and Waybar configuration directories if the HyDE
preset was also applied.

## Upstream and license

This is a modified fork of
[enhaoswen/Tide-island](https://github.com/enhaoswen/Tide-island). General Tide
issues and improvements should be checked against upstream; HyDE integration
changes belong in this fork.

Licensed under the GNU General Public License v3.0. See [`LICENSE`](LICENSE).
