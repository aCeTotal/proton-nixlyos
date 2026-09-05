#!/usr/bin/env bash
# Clone or update the Proton base tree (top level only, no submodules -
# fetch-components.sh handles those so overridden ones are never fetched
# twice). Partial clone (tree:0) instead of shallow: `git apply --3way`
# in apply-patches.sh lazily fetches the base blobs it needs.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

read -r url branch <<< "$(source_for proton)"

if [ -d "$SRC/.git" ]; then
    log "updating proton ($branch)"
    # Migrate pre-existing shallow clones (no promisor, 3-way apply breaks).
    [ -f "$SRC/.git/shallow" ] && git -C "$SRC" fetch --unshallow --filter=tree:0 origin "$branch"
    git -C "$SRC" fetch --filter=tree:0 origin "$branch"
    git -C "$SRC" checkout -q -B "$branch" FETCH_HEAD
else
    log "cloning proton ($branch)"
    mkdir -p "$WORK"
    git clone --filter=tree:0 --branch "$branch" "$url" "$SRC"
fi

log "proton at $(git -C "$SRC" rev-parse --short HEAD)"
