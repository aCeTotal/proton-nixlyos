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

tarball="$(ls -t "$OUT"/*.tar.xz 2>/dev/null | head -1)"
[ -n "$tarball" ] || die "no tarball in $OUT - run the build first"
name="$(basename "$tarball" .tar.xz)"
tag="${name#"$BUILD_NAME"-}"

log "publishing $name (tag $tag)"
if ! gh release view "$tag" --repo "$REPO" > /dev/null 2>&1; then
    gh release create "$tag" --repo "$REPO" \
        --title "$name" --notes "Automated build $name" \
        "$tarball" "$tarball.sha256"
else
    warn "release $tag already exists, uploading assets with --clobber"
    gh release upload "$tag" --repo "$REPO" --clobber \
        "$tarball" "$tarball.sha256"
fi

pin="$NIXLYPKGS/pkgs/proton-nixlyos/pin.json"
[ -d "$(dirname "$pin")" ] || die "nixlypkgs not found at $NIXLYPKGS (set NIXLYPKGS=...)"
hash="$(nix hash file --sri "$tarball")"
cat > "$pin" <<EOF
{
  "version": "$tag",
  "url": "https://github.com/$REPO/releases/download/$tag/$name.tar.xz",
  "hash": "$hash"
}
EOF
log "updated $pin"
log "next: commit+push nixlypkgs, then 'nix flake update nixlypkgs' + rebuild in .nixlyos"
