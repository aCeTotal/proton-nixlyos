#!/usr/bin/env bash
# Populate component trees inside the Proton checkout.
# - Components listed in sources.conf are cloned directly at the latest
#   tip of their configured repo/branch (replacing Valve's pinned
#   submodule), recursing into their own submodules.
# - Every other Proton submodule is initialized at Valve's pinned commit.
# - protonfixes is not a Valve submodule and is cloned into the tree at
#   protonfixes/, where the cachyos fork patches build and package it.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
resolve="$(dirname "${BASH_SOURCE[0]}")/resolve-branch.sh"

overrides="wine dxvk vkd3d-proton dxvk-nvapi"

# Update in place when the clone already exists with the same origin
# (fast incremental runs), otherwise clone fresh. Partial clone (tree:0)
# instead of shallow so `git apply --3way` can lazily fetch base blobs.
sync_tip() { # <url> <branch> <dir>
    if [ -d "$3/.git" ] \
        && [ "$(git -C "$3" remote get-url origin 2>/dev/null)" = "$1" ]; then
        # Migrate pre-existing shallow clones (no promisor for 3-way apply).
        [ -f "$3/.git/shallow" ] \
            && git -C "$3" fetch --unshallow --filter=tree:0 origin "$2"
        git -C "$3" fetch --filter=tree:0 origin "$2"
        git -C "$3" checkout -q -B "${2##*/}" FETCH_HEAD
        git -C "$3" reset --hard -q FETCH_HEAD
        git -C "$3" submodule update --init --recursive --depth 1 \
            || git -C "$3" submodule update --init --recursive
    else
        rm -rf "$3"
        git clone --filter=tree:0 --branch "$2" --recurse-submodules \
            --shallow-submodules "$1" "$3"
    fi
}

for comp in $overrides protonfixes; do
    read -r url branch <<< "$(source_for "$comp")"
    [ "$branch" = auto ] && branch="$(bash "$resolve" "$url")"
    dir="$(component_dir "$comp")"
    log "fetching $comp ($branch)"
    sync_tip "$url" "$branch" "$dir"
    log "$comp at $(git -C "$dir" rev-parse --short HEAD)"
done

log "initializing remaining Valve submodules"
git -C "$SRC" config -f .gitmodules --get-regexp '\.path$' \
    | awk '{print $2}' \
    | while read -r path; do
        case " $overrides " in *" $path "*) continue ;; esac
        # Skip stale .gitmodules entries with no gitlink in the tree.
        [ -n "$(git -C "$SRC" ls-tree HEAD "$path")" ] || continue
        git -C "$SRC" submodule update --init --recursive --depth 1 -- "$path" \
            || git -C "$SRC" submodule update --init --recursive -- "$path"
    done
