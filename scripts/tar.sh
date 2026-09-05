#!/usr/bin/env bash
# Orchestrator behind `nix run .#tar`: fetch everything at its latest,
# patch, build in the Steam Runtime container, assemble the tarball.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
here="$(dirname "${BASH_SOURCE[0]}")"

log "state dir:  $PN_STATE"
log "build name: $BUILD_NAME"
mkdir -p "$WORK" "$OUT"

bash "$here/fetch-proton.sh"
bash "$here/fetch-components.sh"
bash "$here/apply-patches.sh"
bash "$here/fetch-fork-submodules.sh"
bash "$here/build.sh"
bash "$here/assemble.sh"
