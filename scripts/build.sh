#!/usr/bin/env bash
# Configure and build Proton via its own container-based build system
# (Steam Runtime SDK image pulled by podman/docker), then `make redist`.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

engine=""
for candidate in podman docker; do
    command -v "$candidate" > /dev/null && { engine="$candidate"; break; }
done
[ -n "$engine" ] || die "podman or docker required (NixOS: virtualisation.podman.enable = true)"

# Rootless podman from nixpkgs has no image signature policy file; without
# one every podman invocation aborts.
if [ "$engine" = podman ] && [ ! -e /etc/containers/policy.json ] \
    && [ ! -e "$HOME/.config/containers/policy.json" ]; then
    log "creating default ~/.config/containers/policy.json for podman"
    mkdir -p "$HOME/.config/containers"
    echo '{"default":[{"type":"insecureAcceptAnything"}]}' \
        > "$HOME/.config/containers/policy.json"
fi

mkdir -p "$BUILD" "$CCACHE_DIR"
cd "$BUILD"

# Same flags as the proton-cachyos release CI builds; the cachyos
# configure.sh turns CFLAGS/RUSTFLAGS into HOST_CFLAGS / HOST_RUSTFLAGS.
# Pre-set environment values win.
case "$PN_VARIANT" in
    v3)      : "${CFLAGS:=-O3 -march=x86-64-v3 -mtune=core-avx2}" ;;
    generic) : "${CFLAGS:=-O3 -march=x86-64 -mtune=generic}" ;;
esac
: "${RUSTFLAGS:=-Copt-level=3 -Ctarget-cpu=nocona}"
export CFLAGS RUSTFLAGS

log "configuring (engine: $engine, build name: $BUILD_NAME, variant: $PN_VARIANT)"
# bash prefix: the script's /bin/bash shebang does not exist on NixOS
# (make's own /bin/bash use is fixed by patches/proton/0101)
bash "$SRC/configure.sh" \
    --build-name="$BUILD_NAME" \
    --container-engine="$engine" \
    --enable-ccache

log "building (this takes a while on first run)"
make redist 2>&1 | tee "$WORK/build.log"

log "build done, log: $WORK/build.log"
