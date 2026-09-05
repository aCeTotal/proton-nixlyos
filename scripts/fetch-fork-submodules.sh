#!/usr/bin/env bash
# Bring submodules to the state the cachyos fork expects. Must run after
# apply-patches.sh, which commits the new .gitmodules entries and
# gitlinks.
# 1. Initialize submodules the fork patches added (extras/, vklayers/,
#    nvidia-libs/, steamrtdeps/, meson, ...) at their pinned commits.
# 2. Check out the pins from config/cachyos-submodules.conf: submodules
#    cachyos moved past Valve's pin (Vulkan-Headers, FEX, ...).
# Overrides and protonfixes already have checkouts and are left alone.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

git -C "$SRC" config -f .gitmodules --get-regexp '\.path$' \
    | awk '{print $2}' \
    | while read -r path; do
        [ -n "$(git -C "$SRC" ls-tree HEAD "$path")" ] || continue
        [ -e "$SRC/$path/.git" ] && continue
        log "initializing $path"
        git -C "$SRC" submodule update --init --recursive --depth 1 -- "$path" \
            || git -C "$SRC" submodule update --init --recursive -- "$path"
    done

grep -Ev '^(#|$)' "$PN_ROOT/config/cachyos-submodules.conf" 2>/dev/null \
    | while IFS='|' read -r path sha; do
        [ -e "$SRC/$path/.git" ] || continue
        [ "$(git -C "$SRC/$path" rev-parse HEAD)" = "$sha" ] && continue
        log "pinning $path to ${sha:0:12}"
        git -C "$SRC/$path" fetch --depth 1 origin "$sha" \
            || git -C "$SRC/$path" fetch origin
        git -C "$SRC/$path" checkout -q "$sha"
        git -C "$SRC/$path" submodule update --init --recursive --depth 1 \
            || git -C "$SRC/$path" submodule update --init --recursive
    done

log "fork submodules ready"
