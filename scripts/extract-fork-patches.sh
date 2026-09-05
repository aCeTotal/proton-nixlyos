#!/usr/bin/env bash
# Regenerate the cachyos fork patches in patches/proton and patches/wine.
#
# proton-cachyos ships its changes as git commits on top of a Valve
# bleeding-edge snapshot (newest cachyos-*-slr tag), and wine-cachyos as
# commits on top of Valve bleeding-edge wine (the wine submodule commit
# that slr tag pins - the dated wine-cachyos branches are base-only
# mirrors). This script rebases those changes onto the CURRENT Valve
# bleeding-edge tips with `git merge-tree` and stores the result as
# 000N-cachyos-*.patch files, so the build applies CachyOS's changes on
# top of whatever Valve bleeding-edge is current.
#
# If Valve and CachyOS changed the same lines, merge-tree reports
# conflicts. Known conflict-prone files are auto-resolved by the rules
# in resolve_mode below (Valve force-pushes bleeding-edge, so this
# happens on most runs); an unknown conflicted file aborts the script -
# add a rule for it after inspecting the conflict. The mirrors live in
# $WORK/fork-mirror/{proton-cachyos,wine}.
#
# Run manually when CachyOS or Valve moves, then commit the regenerated
# patches. Not part of the build pipeline.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

MIRROR="$WORK/fork-mirror"
mkdir -p "$MIRROR"

newest_tag() { # <dir> <suffix>  -> newest cachyos-<ver>-<date>-<suffix> tag
    git -C "$1" tag -l "cachyos-*-$2" \
        | grep -E "^cachyos-[0-9.]+-[0-9]{8}-$2\$" \
        | sort -t- -k3,3 | tail -1
}

# How to resolve a merge conflict in a known conflict-prone file.
#   union  - keep both sides (independent additions colliding on context)
#   ours   - keep Valve's side (cachyos side is stale pre-rebase content)
#   theirs - keep cachyos's side (their feature supersedes Valve's)
#   craft  - file-specific rewrite (see craft_blob)
resolve_mode() { # <repo> <path>
    case "$1:$2" in
        proton:Makefile.in)                 echo union ;;
        proton:proton)                      echo union ;;
        proton:make/rules-meson.mk)         echo craft ;;
        wine:dlls/amdxc64/*)                echo theirs ;;
        wine:dlls/atiadlxx/atiadlxx_main.c) echo union ;;
        wine:dlls/mfreadwrite/reader.c)     echo union ;;
        wine:dlls/ntdll/unix/env.c)         echo union ;;
        wine:dlls/ntdll/unix/virtual.c)     echo union ;;
        wine:dlls/winegstreamer/wm_reader.c) echo union ;;
        wine:*)                             echo ours ;;
        *)                                  echo none ;;
    esac
}

# Strip conflict markers, keeping the side(s) given by mode.
strip_markers() { # union|ours|theirs
    awk -v mode="$1" '
        /^<<<<<<</ {state="ours"; next}
        /^=======$/ && state=="ours" {state="theirs"; next}
        /^>>>>>>>/ && state=="theirs" {state=""; next}
        state=="ours" && mode=="theirs" {next}
        state=="theirs" && mode=="ours" {next}
        {print}'
}

# File-specific resolutions that need more than side-picking.
craft_blob() { # <dir> <ours> <theirs> <path> -> blob sha
    case "$4" in
    make/rules-meson.mk)
        # Valve's current file (split c/cpp_link_args), with cachyos's
        # changes re-applied: env CFLAGS before per-target CFLAGS, and
        # meson from the in-tree submodule instead of the SDK's.
        git -C "$1" show "$2:$4" \
            | sed -E 's|^(c(pp)?_args = .*)\$\$\(\$\(2\)_\$\(3\)_CFLAGS\) \$\$\(CFLAGS\)\)\]|\1$$(CFLAGS) $$($(2)_$(3)_CFLAGS))]|' \
            | sed -e 's|^\$\$(OBJ)/\.\$(1)-\$(3)-configure: \$\$(\$(2)_SRC)/meson\.build$|&\ meson-source|' \
                  -e 's|^	meson "\$\$(\$(2)_\$(3)_OBJ)" "\$\$(\$(2)_SRC)" \\$|	$$(OBJ)/src-meson/meson.py "$$($(2)_$(3)_OBJ)" "$$($(2)_SRC)" \\|' \
            | git -C "$1" hash-object -w --stdin
        ;;
    *) die "craft_blob: no recipe for $4" ;;
    esac
}

# Rebase <theirs> onto <ours> as a tree object, 3-way against <mb>.
# The merge base is computed from cachyos refs only - Valve force-pushes
# bleeding-edge, so merge-base against the Valve tip degrades to an
# ancient ancestor and produces spurious conflicts. Content conflicts
# are resolved per resolve_mode; an unknown file aborts.
rebased_tree() { # <dir> <repo-name> <ours> <theirs> <mb>
    local dir="$1" repo="$2" ours="$3" theirs="$4" mb="$5"
    local out tree path mode blob mode_bits
    out="$(git -C "$dir" merge-tree --write-tree --merge-base="$mb" \
        "$ours" "$theirs" 2>/dev/null)" && { echo "$out" | head -1; return; }
    tree="$(echo "$out" | head -1)"
    export GIT_INDEX_FILE="$MIRROR/.resolve-index"
    rm -f "$GIT_INDEX_FILE"
    git -C "$dir" read-tree "$tree"
    while read -r path; do
            mode_bits="$(git -C "$dir" ls-tree "$tree" "$path" | awk '{print $1}')"
            # Submodule pointer conflicts: excluded from the patches,
            # pinned via cachyos-submodules.conf instead.
            [ "$mode_bits" = 160000 ] && continue
            mode="$(resolve_mode "$repo" "$path")"
            case "$mode" in
                union|ours|theirs)
                    blob="$(git -C "$dir" cat-file blob "$tree:$path" \
                        | strip_markers "$mode" \
                        | git -C "$dir" hash-object -w --stdin)" ;;
                craft)
                    blob="$(craft_blob "$dir" "$ours" "$theirs" "$path")" ;;
                *)
                    die "unresolved conflict in $repo:$path - inspect and add a resolve_mode rule" ;;
            esac
            git -C "$dir" update-index --cacheinfo "$mode_bits,$blob,$path"
            warn "auto-resolved $repo:$path ($mode)"
    done < <(echo "$out" | sed -n 's/^CONFLICT ([^)]*): Merge conflict in //p')
    git -C "$dir" write-tree
    unset GIT_INDEX_FILE
}

# Emit one patch file: header + git diff of the given pathspecs.
emit() { # <dir> <base> <tip> <outfile> <pathspec...>
    local dir="$1" base="$2" tip="$3" out="$4"; shift 4
    git -C "$dir" diff --binary --full-index "$base" "$tip" -- "$@" > "$out.tmp"
    if [ ! -s "$out.tmp" ]; then
        rm -f "$out.tmp" "$out"
        warn "$(basename "$out"): empty, skipped"
        return
    fi
    { printf 'Generated by scripts/extract-fork-patches.sh\nSource: %s\nRebased onto: %s\n\n' \
        "$SRC_DESC" "$BASE_DESC"; cat "$out.tmp"; } > "$out"
    rm -f "$out.tmp"
    log "wrote $(basename "$out") ($(grep -c '^diff --git' "$out") files)"
}

### proton ###
pdir="$MIRROR/proton-cachyos"
if [ ! -d "$pdir/.git" ]; then
    git clone --filter=blob:none --no-checkout \
        https://github.com/CachyOS/proton-cachyos.git "$pdir"
    git -C "$pdir" remote add valve https://github.com/ValveSoftware/Proton.git
fi
git -C "$pdir" fetch --filter=blob:none origin --tags
git -C "$pdir" fetch --filter=blob:none valve bleeding-edge

slr="$(newest_tag "$pdir" slr)"
basetag="$(newest_tag "$pdir" base)"
[ -n "$slr" ] && [ -n "$basetag" ] || die "cachyos slr/base tags not found"
pmb="$(git -C "$pdir" merge-base "$slr" "$basetag")"
ptree="$(rebased_tree "$pdir" proton valve/bleeding-edge "$slr" "$pmb")"
SRC_DESC="proton-cachyos $slr"
BASE_DESC="Proton bleeding-edge $(git -C "$pdir" rev-parse --short valve/bleeding-edge)"
log "proton: $SRC_DESC -> $BASE_DESC"

# Submodule pointer moves are excluded from the patches (a later
# `git add -A` while committing patches would revert them from the
# worktree anyway). Instead the cachyos pins for non-override submodules
# are written to config/cachyos-submodules.conf, and
# fetch-fork-submodules.sh checks those out after patching - cachyos's
# build rules depend on these versions (e.g. Vulkan-Utility-Libraries
# needs cachyos's newer Vulkan-Headers). Overrides are synced by
# fetch-components.sh, protonfixes is cloned into the tree by it.
overrides="wine dxvk vkd3d-proton dxvk-nvapi"
moved_gitlinks="$(git -C "$pdir" diff --raw "$pmb" "$slr" \
    | awk '$1==":160000" && $2=="160000" {print $NF}')"
conf="$PN_ROOT/config/cachyos-submodules.conf"
{
    printf '# Submodules proton-cachyos pins at other commits than Valve.\n'
    printf '# path|commit - generated by extract-fork-patches.sh (%s),\n' "$slr"
    printf '# checked out by fetch-fork-submodules.sh after patching.\n'
    for p in $moved_gitlinks; do
        case " $overrides " in *" $p "*) continue ;; esac
        echo "$p|$(git -C "$pdir" ls-tree "$slr" "$p" | awk '{print $3}')"
    done
} > "$conf"
log "wrote $(basename "$conf") ($(grep -cv '^#' "$conf") pins)"

exclude=(':(exclude).github' ':(exclude)protonfixes')
for p in $moved_gitlinks; do exclude+=(":(exclude)$p"); done

out="$PN_ROOT/patches/proton"
emit "$pdir" valve/bleeding-edge "$ptree" "$out/0001-cachyos-build-system.patch" \
    .gitmodules Makefile.in configure.sh default_pfx.py make \
    extras vklayers nvidia-libs steamrtdeps meson "${exclude[@]}"
emit "$pdir" valve/bleeding-edge "$ptree" "$out/0002-cachyos-proton-script.patch" \
    proton utilities.py vulkan.py steam_helper umu_helper \
    vrclient_x64 wineopenxr "${exclude[@]}"
# patches/protonfixes is dropped: those are backports for the
# protonfixes commit cachyos pins, and we track umu-protonfixes master
# which already contains them (they fail as already-applied/stale).
emit "$pdir" valve/bleeding-edge "$ptree" "$out/0003-cachyos-intree-patches.patch" \
    patches ':(exclude)patches/protonfixes'
emit "$pdir" valve/bleeding-edge "$ptree" "$out/0004-cachyos-locale.patch" locale

# Anything the groups above missed lands in a misc patch so nothing is
# silently dropped when cachyos touches new paths.
grouped=':(exclude).gitmodules :(exclude)Makefile.in :(exclude)configure.sh
:(exclude)default_pfx.py :(exclude)make :(exclude)extras :(exclude)vklayers
:(exclude)nvidia-libs :(exclude)steamrtdeps :(exclude)meson :(exclude)proton
:(exclude)utilities.py :(exclude)vulkan.py :(exclude)steam_helper
:(exclude)umu_helper :(exclude)vrclient_x64 :(exclude)wineopenxr
:(exclude)patches :(exclude)locale'
emit "$pdir" valve/bleeding-edge "$ptree" "$out/0005-cachyos-misc.patch" \
    . $grouped "${exclude[@]}"

### wine ###
wdir="$MIRROR/wine"
if [ ! -d "$wdir/.git" ]; then
    git clone --filter=blob:none --no-checkout --single-branch \
        --branch bleeding-edge https://github.com/ValveSoftware/wine.git "$wdir"
    git -C "$wdir" remote add cachy https://github.com/CachyOS/wine-cachyos.git
fi
git -C "$wdir" fetch --filter=blob:none origin bleeding-edge

# The wine base is the valve wine commit the cachyos base tag pins
# (stable in the cachyos repo even when Valve force-pushes).
wine_pin="$(git -C "$pdir" ls-tree "$slr" wine | awk '{print $3}')"
wine_base="$(git -C "$pdir" ls-tree "$pmb" wine | awk '{print $3}')"
git -C "$wdir" fetch --filter=blob:none cachy "$wine_pin"
git -C "$wdir" fetch --filter=blob:none cachy "$wine_base" 2>/dev/null \
    || git -C "$wdir" fetch --filter=blob:none origin "$wine_base"
wmb="$(git -C "$wdir" merge-base "$wine_pin" "$wine_base")"
wtree="$(rebased_tree "$wdir" wine origin/bleeding-edge "$wine_pin" "$wmb")"

# The audio/media stack is one tightly coupled unit (winegstreamer,
# winedmo, winepulse/mmdevapi timing, wmadmod, plus the ffmpeg/gstreamer
# submodule pins above): Valve and cachyos each rework it as a whole, so
# line-level merging mixes incompatible generations. Take cachyos's
# shipped state wholesale.
wine_cachy_paths="dlls/winegstreamer dlls/winedmo dlls/winepulse.drv
    dlls/mmdevapi dlls/wmadmod"
export GIT_INDEX_FILE="$MIRROR/.media-index"
rm -f "$GIT_INDEX_FILE"
git -C "$wdir" read-tree "$wtree"
for p in $wine_cachy_paths; do
    git -C "$wdir" rm --cached -r -q "$p"
    git -C "$wdir" read-tree --prefix="$p/" "$wine_pin:$p"
done
wtree="$(git -C "$wdir" write-tree)"
unset GIT_INDEX_FILE
SRC_DESC="wine-cachyos $(git -C "$wdir" rev-parse --short "$wine_pin") ($slr pin)"
BASE_DESC="wine bleeding-edge $(git -C "$wdir" rev-parse --short origin/bleeding-edge)"
log "wine: $SRC_DESC -> $BASE_DESC"

emit "$wdir" origin/bleeding-edge "$wtree" \
    "$PN_ROOT/patches/wine/0001-cachyos-wine.patch"

log "extraction done - review and commit the regenerated patches"
