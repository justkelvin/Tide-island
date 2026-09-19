#!/usr/bin/env bash
set -euo pipefail

tide_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

cmake -S "$tide_root" -B "$tide_root/build" -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON "$@"
cmake --build "$tide_root/build" --parallel "$(nproc 2>/dev/null || echo 4)"
