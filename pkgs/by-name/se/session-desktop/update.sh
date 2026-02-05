#!/usr/bin/env nix-shell
#!nix-shell -i bash -p nix-update

set -euo pipefail

nix-update session-desktop

yarnLock="$(nix-build -A session-desktop.src --no-out-link)/yarn.lock"
depVersion() {
  name="$(echo "$1" | sed 's/\//\\&/g')"
  awk '/^"?'"$name"'@/ {flag=1; next} flag && /^  version "[^"]+"/ {match($0, /^  version "([^"]+)"/, a); print a[1]; exit}' "$yarnLock"
}

nix-update session-desktop.passthru.libsession-util-nodejs --version "$(depVersion libsession_util_nodejs)"
