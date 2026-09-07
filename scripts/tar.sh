#!/usr/bin/env bash
# Orchestrator behind `nix run .#tar`: fetch everything at its latest,
# patch, then build + assemble one tarball per variant (v3 and generic)
# in the Steam Runtime container. PN_VARIANTS="v3" limits the set.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
here="$(dirname "${BASH_SOURCE[0]}")"

log "state dir:  $PN_STATE"
log "build name: $BUILD_NAME"
mkdir -p "$WORK" "$OUT"

bash "$here/fetch-proton.sh"
bash "$here/fetch-components.sh"
bash "$here/apply-patches.sh"
bash "$here/fetch-fork-submodules.sh"
for variant in ${PN_VARIANTS:-v3 generic}; do
    PN_VARIANT=$variant bash "$here/build.sh"
    PN_VARIANT=$variant bash "$here/assemble.sh"
done
