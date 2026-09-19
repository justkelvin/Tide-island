# Maintainer: whysooraj <whysooraj.official@gmail.com>
pkgname=tide-island
pkgver=1.0.35
pkgrel=1
_srcdir=Tide-island-$pkgver
_builddir=build-$pkgver
pkgdesc="A dynamic island for Hyprland using Quickshell"
arch=('x86_64')
url="https://github.com/enhaoswen/Tide-island"
license=('GPL-3.0-only')
depends=(
    'qt6-base'
    'qt6-declarative'
    'qt6-5compat'
    'qt6-wayland'
    'qt6-svg'
    'wireplumber'
    'pipewire'
    'dbus'
    'libpulse'
    'systemd'
    'brightnessctl'
    'upower'
    'bluez'
    'bluez-utils'
    'quickshell'
)
makedepends=('cmake')
options=('!debug' '!strip')
optdepends=(
    'hyprland: for Hyprland compositor integration'
    'hyprsunset: for Night Light on Hyprland'
    'cava: for audio visualizer'
)
conflicts=('tide-island-git')
install='tide-island.install'
source=("$pkgname-$pkgver.tar.gz::https://github.com/enhaoswen/Tide-island/archive/refs/tags/$pkgver.tar.gz")
sha256sums=('SKIP')

build() {
  cmake -S "$_srcdir" -B "$_builddir" \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_BUILD_TYPE=Release
  cmake --build "$_builddir"
}

package() {
  DESTDIR="$pkgdir" cmake --install "$_builddir"
  rm -f "$pkgdir/usr/lib/qt6/qml/TideIsland/tide-island-config-app_qml_module_dir_map.qrc"
  chmod +x "$pkgdir/usr/bin/tide-island"
  chmod +x "$pkgdir/usr/bin/tide-island-config-app"
  chmod +x "$pkgdir/usr/share/tide-island/bin/lyricsmpris"
}
