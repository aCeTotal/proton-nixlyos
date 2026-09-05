#!/usr/bin/env bash
# Assemble the final tarball from the redist build:
#   - copy the redist tree to a stage directory
#   - add protonfixes + local gamefix overlays (fixes/gamefixes/*.py)
#   - hook protonfixes into the proton launcher script
#   - pack out/<name>-<date>-<sha>.tar.xz + sha256
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

redist=""
for dir in "$BUILD/redist" "$BUILD"/redist-*; do
    [ -f "$dir/proton" ] && { redist="$dir"; break; }
done
if [ -z "$redist" ]; then
    tarball="$(ls -t "$BUILD"/*.tar.* 2>/dev/null | head -1 || true)"
    [ -n "$tarball" ] || die "no redist output found under $BUILD"
    rm -rf "$WORK/redist-unpacked"
    mkdir -p "$WORK/redist-unpacked"
    tar -xf "$tarball" -C "$WORK/redist-unpacked"
    redist="$(dirname "$(find "$WORK/redist-unpacked" -maxdepth 2 -name proton | head -1)")"
    [ -f "$redist/proton" ] || die "no proton script inside $tarball"
fi

log "staging redist from $redist"
rm -rf "$STAGE"
mkdir -p "$STAGE/$BUILD_NAME"
cp -a "$redist/." "$STAGE/$BUILD_NAME/"

# The cachyos fork patches make the Proton build package protonfixes
# itself; only add it here if this redist predates that.
if [ ! -d "$STAGE/$BUILD_NAME/protonfixes" ]; then
    log "adding protonfixes"
    cp -a "$PROTONFIXES" "$STAGE/$BUILD_NAME/protonfixes"
    rm -rf "$STAGE/$BUILD_NAME/protonfixes/.git"
fi

for fix in "$PN_ROOT/fixes/gamefixes"/*.py; do
    [ -e "$fix" ] || break
    log "overlaying local gamefixes"
    cp "$PN_ROOT/fixes/gamefixes"/*.py \
        "$STAGE/$BUILD_NAME/protonfixes/gamefixes-steam/"
    break
done

if ! grep -q '^import protonfixes' "$STAGE/$BUILD_NAME/proton"; then
    log "hooking protonfixes into proton script"
    sed -i 's|^if __name__ == "__main__":|import protonfixes\n\nif __name__ == "__main__":|' \
        "$STAGE/$BUILD_NAME/proton"
    grep -q '^import protonfixes' "$STAGE/$BUILD_NAME/proton" \
        || die "could not hook protonfixes into proton script"
fi

mkdir -p "$OUT"
name="$BUILD_NAME-$(date +%Y%m%d)-$(git -C "$SRC" rev-parse --short HEAD)"
log "packing $name.tar.xz"
tar -C "$STAGE" -cJf "$OUT/$name.tar.xz" "$BUILD_NAME"
(cd "$OUT" && sha256sum "$name.tar.xz" > "$name.tar.xz.sha256")

log "done: $OUT/$name.tar.xz"
