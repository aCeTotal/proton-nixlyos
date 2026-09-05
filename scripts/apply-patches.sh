#!/usr/bin/env bash
# Apply local patches ($PN_ROOT/patches/<comp>/) to each component,
# lexicographic order. The 0001..000N-cachyos-* patches carry the
# proton-cachyos / wine-cachyos fork changes rebased onto Valve
# bleeding-edge (see extract-fork-patches.sh); higher numbers are ours.
# A failing patch aborts the build - regenerate the cachyos patches if
# Valve moved past them.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

components="proton wine dxvk vkd3d-proton dxvk-nvapi protonfixes"

# Each success is committed so a later failed --3way can be cleaned up
# with reset --hard without reverting earlier patches.
apply_one() { # <dir> <patch>
    if git -C "$1" apply --3way --whitespace=nowarn "$2" 2>/dev/null; then
        git -C "$1" add -A
        git -C "$1" -c user.name=proton-nixlyos -c user.email=pn@localhost \
            commit -q -m "patch: $(basename "$2")"
        log "applied $(basename "$2")"
    else
        git -C "$1" reset --hard -q HEAD
        die "local patch failed: $2"
    fi
}

for comp in $components; do
    dir="$(component_dir "$comp")"
    [ -d "$dir" ] || continue
    for patch in "$PN_ROOT/patches/$comp"/*.patch; do
        [ -e "$patch" ] || continue
        apply_one "$dir" "$patch"
    done
done

log "patching done"
