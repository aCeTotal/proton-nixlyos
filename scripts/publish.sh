#!/usr/bin/env bash
# Publish the newest tarball in out/ as a GitHub release on
# aCeTotal/proton-nixlyos and update the nixlypkgs pin so
# `pkgs.proton-nixlyos` installs it.
#
# Needs an authenticated gh (run `gh auth login` once). After this:
#   1. commit + push nixlypkgs
#   2. in .nixlyos: nix flake update nixlypkgs && rebuild
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

NIXLYPKGS="${NIXLYPKGS:-$HOME/git/nixlypkgs}"
REPO="aCeTotal/proton-nixlyos"

gh() {
    if [ -n "$(type -P gh)" ]; then command gh "$@"; else
        nix run nixpkgs#gh -- "$@"
    fi
}

# Tag from the newest tarball; both variants of that tag must exist.
newest="$(ls -t "$OUT"/*.tar.xz 2>/dev/null | head -1)"
[ -n "$newest" ] || die "no tarball in $OUT - run the build first"
tag="$(basename "$newest" .tar.xz)"
tag="${tag#"$BUILD_NAME"-}"
tag="${tag%-v3}"; tag="${tag%-generic}"

assets=()
for variant in v3 generic; do
    t="$OUT/$BUILD_NAME-$tag-$variant.tar.xz"
    [ -f "$t" ] || die "missing $variant tarball for tag $tag - run the build first"
    assets+=("$t" "$t.sha256")
done

log "publishing $BUILD_NAME-$tag (v3 + generic)"
if ! gh release view "$tag" --repo "$REPO" > /dev/null 2>&1; then
    gh release create "$tag" --repo "$REPO" \
        --title "$BUILD_NAME-$tag" --notes "Automated build $BUILD_NAME-$tag" \
        "${assets[@]}"
else
    warn "release $tag already exists, uploading assets with --clobber"
    gh release upload "$tag" --repo "$REPO" --clobber "${assets[@]}"
fi

pin="$NIXLYPKGS/pkgs/proton-nixlyos/pin.json"
[ -d "$(dirname "$pin")" ] || die "nixlypkgs not found at $NIXLYPKGS (set NIXLYPKGS=...)"
hash_v3="$(nix hash file --sri "$OUT/$BUILD_NAME-$tag-v3.tar.xz")"
hash_generic="$(nix hash file --sri "$OUT/$BUILD_NAME-$tag-generic.tar.xz")"
url="https://github.com/$REPO/releases/download/$tag/$BUILD_NAME-$tag"
cat > "$pin" <<EOF
{
  "version": "$tag",
  "variants": {
    "v3": {
      "url": "$url-v3.tar.xz",
      "hash": "$hash_v3"
    },
    "generic": {
      "url": "$url-generic.tar.xz",
      "hash": "$hash_generic"
    }
  }
}
EOF
log "updated $pin"
log "next: commit+push nixlypkgs, then 'nix flake update nixlypkgs' + rebuild in .nixlyos"
