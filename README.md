<h1 align="center">Tide Island</h1>

<p align="center">
  <b>A smooth, lightweight, and flexible interactive Dynamic Island for Hyprland.</b>
</p>

<p align="center">
  <a href="https://github.com/enhaoswen/Tide-island/stargazers"><img alt="GitHub stars" src="https://img.shields.io/github/stars/enhaoswen/Tide-island?style=flat-square&color=8aadf4"></a>
  <a href="https://github.com/enhaoswen/Tide-island/issues"><img alt="GitHub issues" src="https://img.shields.io/github/issues/enhaoswen/Tide-island?style=flat-square&color=8aadf4"></a>
  <a href="https://aur.archlinux.org/packages/tide-island"><img alt="AUR package" src="https://img.shields.io/aur/version/tide-island?style=flat-square&label=AUR&color=8aadf4"></a>
  <img alt="Hyprland" src="https://img.shields.io/badge/Hyprland-111111?style=flat-square&color=8aadf4">
  <img alt="C++ + Qt" src="https://img.shields.io/badge/C%2B%2B%20%2B%20Qt-111111?style=flat-square&color=8aadf4">
</p>

<p align="center">
  <a href="#preview">Preview</a>
  ·
  <a href="#features">Features</a>
  ·
  <a href="#installation">Installation</a>
  ·
  <a href="#configuration">Configuration</a>
  ·
  <a href="#common-commands">Common Commands</a>
  ·
  <a href="#hyde--waybar-integration">HyDE / Waybar Integration</a>
</p>

---

## About Tide Island

Tide Island is a small desktop widget for Hyprland, styled like the Dynamic Island.

When nothing much is going on, it just sits in the corner, staying out of the way. When you need to check some information, it expands into a panel where you can view lyrics, switch workspaces, adjust system settings, check notifications, or put in some custom content.

It's built with Quickshell, QML, and C++/Qt 6. Most of the effort went into making the animations as smooth as possible, interactions responsive, and resource usage kept in check. I can't claim it's anything special, but I hope it's comfortable to use.

<br>

## Preview

### Tide Island
<table>
  <tr>
    <td width="50%">
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/mp.png" width="100%" alt="Music player" />
    </td>
    <td width="50%">
      <img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/msg.png" width="100%" alt="Message preview" />
    </td>
  </tr>
</table>

### Config App

<img src="https://raw.githubusercontent.com/enhaoswen/Tide-island/display/Preview/config_app.png" width = "90%">
<br>

## Features

- Clock
- Music player
- Lyrics displayer
- Custom page
- Notification popups



### System Feedback

- Volume changes
- Brightness changes
- Battery charging / discharging
- Workspace changes
- Media playback (optional)
- System notifications



### Custom Page

- Time
- Date
- Battery
- Volume
- CPU usage
- Current workspace
- Memory usage
- Brightness
- Cava
- Storage usage

### Compositor support

- Hyprland: full current experience, including workspace animations, shortcuts, and Night Light through `hyprsunset`.

<br>

## Installation

### Arch Linux

Install from the AUR:

```bash
yay -S tide-island
```

### Other Linux distributions

Download the source package and checksum from the
[latest GitHub Release](https://github.com/enhaoswen/Tide-island/releases/latest):

```bash
curl -fLO https://github.com/enhaoswen/Tide-island/releases/latest/download/tide-island-source.tar.xz
curl -fLO https://github.com/enhaoswen/Tide-island/releases/latest/download/SHA256SUMS
sha256sum --check SHA256SUMS
tar -xf tide-island-source.tar.xz
cd Tide-island-*
./install.sh
```

The installer writes Tide Island to `/usr` and can automatically install
dependencies on:

- Debian, Ubuntu, and derivatives using `apt`
- Fedora, RHEL, and derivatives using `dnf`
- openSUSE using `zypper`

For other distributions, install the dependencies manually and run:

```bash
./install.sh --skip-deps
```

Quickshell is used from `/usr/bin/quickshell` when available. Otherwise the
installer builds the pinned, verified Quickshell version compatible with this
release. Qt 6.6 or newer is required.

This source installer targets conventional Linux systems with a writable
`/usr`. Declarative or immutable systems such as NixOS and Fedora Silverblue
should use a native package or a mutable development container instead.

Useful installer options:

| Option | Description |
| --- | --- |
| `./install.sh --no-service` | Install Tide Island without enabling or starting the systemd user service. |
| `./install.sh --skip-quickshell` | Skip building Quickshell from source and use the existing `/usr/bin/quickshell`; installation stops with an error if that file does not exist. |
| `./install.sh --force-build-quickshell` | Rebuild and install the project's pinned Quickshell version even when Quickshell is already installed. |
| `./install.sh --uninstall` | Remove the Tide Island files installed by the source installer; installed dependencies and Quickshell are kept. |

### Building from source (development)

If you're working on the code and want to install directly from your local checkout:

```bash
# Configure once — PREFIX=/usr is required so the launcher and QML module
# land where Quickshell and systemd expect them
cmake -GNinja -S . -B build -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=/usr

# Build and install
cmake --build build --parallel
sudo cmake --install build

# Start the service
systemctl --user restart tide-island
```

After the first configure, the iteration loop is just:

```bash
cmake --build build --parallel && sudo cmake --install build && systemctl --user restart tide-island
```

Each install overwrites the previous one with no manifest or package-manager involvement.

<br>

## Starting Tide Island

Tide Island provides a systemd user service.

Enable and start it immediately (Recommended):

```bash
systemctl --user enable --now tide-island.service
```

If you want to manage startup manually, add this to your `hyprland.conf`:

```conf
exec-once = tide-island
```

Or add this to `hyprland.lua`:

```lua
hl.exec_once("tide-island")
```

If the systemd service is already enabled, you do not need to add `exec-once`.

<br>

## Configuration

Search `Tide Island Settings` in any application launcher.

### Timer

Open the secondary panel (right-click by default) and choose **Set Timer**, or
hold the left mouse button on the collapsed pill for half a second and release.
The pill compresses slightly while held; dragging still performs a swipe.
If a timer is already active, either entry opens its controls instead.
Drag the ruler left/right or scroll
to adjust seconds; click the ruler to switch between seconds and minutes without
changing the selected duration. Click **Start Timer** to begin.

While running or paused, the idle pill shows a countdown ring, the normal clock,
and the remaining time. Click it for pause/resume and cancel controls; click the
preview's empty space to dismiss it immediately. Otherwise,
the controls collapse after 10 seconds. Cancel restores the clock and any playing media.
At zero, a short chime plays and **Timer done** appears for five seconds.

The timer takes precedence over media in the idle pill and is shared across
screens. Durations range from one second to 24 hours. Timers live for the current
shell session; restarting Tide Island clears them. Hover no longer opens the
timer editor; the existing media hover preference applies again.

## Common Commands

#### Restart after editing the configuration:

```bash
systemctl --user restart tide-island
```

#### Stop Tide Island:

```bash
systemctl --user stop tide-island
```

#### View logs:

```bash
journalctl --user -u tide-island -f
```

<br>

## HyDE / Waybar Integration

This fork can run Tide embedded in a HyDE Waybar bar instead of as a fully
independent panel:

- Tide watches `~/.config/waybar/theme.css` and tints its capsule background
  with Waybar's `@define-color main-bg` color, blended with the
  `islandBackgroundOpacity` setting, so it visually matches your active
  Waybar theme.
- Tide's window sets `exclusionMode: ExclusionMode.Ignore` and renders on the
  Wayland `Overlay` layer under the `tide-island` namespace, so it shares
  Waybar's top strip instead of reserving its own space and pushing Waybar
  down (or being pushed below it).

A ready-to-use Waybar layout/style preset and Tide configuration matching
this setup are provided in [`integrations/hyde`](integrations/hyde/README.md),
along with full installation steps and notes on avoiding duplicate
notifications with Dunst.

<br>

## Contributing

Issues, bug reports, design suggestions, and pull requests are all welcome.

-  only 1 topic per issue.
-  tell your ideas first before making a PR

## Acknowledgments

Thanks to:

- [@end-4](https://github.com/end-4) for the workspace overview design inspiration
- [@gozhuimeng](https://github.com/gozhuimeng) for improving the lyrics backend
- [@LatifKovani](https://github.com/LatifKovani) for a significant improvement

## Community

- Discord:https://discord.gg/Rcj3uPtKwD
- Email: enhaoswen@gmail.com

---

<p align="center">
  <sub>
    Made for Wayland users who like quiet and practical desktops.
  </sub>
</p>
