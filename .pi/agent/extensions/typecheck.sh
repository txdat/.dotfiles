#!/usr/bin/env bash
# Type-check the Pi extensions with TypeScript 7 against the installed Pi
# release, whose API types they import. `pi update` moves that release, so this
# derives its path from the managed install instead of pinning it in tsconfig.
set -euo pipefail

DIR=$(dirname -- "$(realpath -- "${BASH_SOURCE[0]}")")
INSTALL=${PI_MANAGED_INSTALL_ROOT:-$HOME/.pi/agent/install}
VERSION_FILE=$INSTALL/current-version
if [[ ! -r "$VERSION_FILE" ]]; then
  printf 'Cannot read the installed Pi version: %s\n' "$VERSION_FILE" >&2
  exit 1
fi
read -r VERSION <"$VERSION_FILE"
TYPES=$INSTALL/releases/$VERSION/node_modules

TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
cat >"$TMP/tsconfig.json" <<JSON
{
  "extends": "$DIR/tsconfig.json",
  "compilerOptions": {
    "paths": {
      "@earendil-works/pi-coding-agent": ["$TYPES/@earendil-works/pi-coding-agent"]
    },
    "typeRoots": ["$TYPES/@types"]
  }
}
JSON
exec tsc -p "$TMP"
