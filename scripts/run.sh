#!/usr/bin/env bash
set -euo pipefail

tide_script="$(readlink -f -- "${BASH_SOURCE[0]}")"
tide_root="$(cd -- "$(dirname -- "$tide_script")/.." && pwd)"

if [[ ! -f "$tide_root/build/IslandBackend/libIslandBackendplugin.so" ]]; then
    "$tide_root/scripts/build.sh"
fi

export QML_IMPORT_PATH="$tide_root/build"
export QUICKSHELL_LYRICS_BACKEND="$tide_root/build/lyricsmpris"
export MALLOC_CONF="narenas:2,background_thread:true,dirty_decay_ms:2000,muzzy_decay_ms:2000"

exec quickshell -p "$tide_root" "$@"
