#!/usr/bin/env bash
set -euo pipefail

tide_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

"$tide_root/scripts/build.sh"

echo "==> Running CTest test suites..."
ctest --test-dir "$tide_root/build" --output-on-failure "$@"

echo "==> Running QML Lint on shell and window..."
qmllint -I "$tide_root/build" "$tide_root/shell.qml" "$tide_root/qml/windows/IslandWindow.qml"

echo "==> All checks passed successfully!"
