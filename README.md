# proton-nixlyos

Bleeding-edge Proton tarball builder in the style of
[proton-cachyos](https://github.com/CachyOS/proton-cachyos), built from
scratch. Every run fetches the latest of everything:

- **Proton**: Valve `bleeding-edge` branch (the base proton-cachyos uses)
- **wine**: Valve `bleeding-edge` wine
- **DXVK / VKD3D-Proton / DXVK-NVAPI**: upstream master
- **protonfixes**: latest umu-protonfixes
- **CachyOS fork changes**: `patches/proton` + `patches/wine` carry the
  proton-cachyos and wine-cachyos changes (extras, vklayers, nvidia-libs,
  FSR4, winepipewire, ...) rebased onto Valve bleeding-edge, so the end
  result matches proton-cachyos while Valve stays updatable. Built with
  the same `x86-64-v3` flags as the proton-cachyos v3 release.

## Usage

```sh
nix run .#tar
```

Fetches everything, builds inside the Steam Runtime SDK container and
produces `out/proton-nixlyos-<date>-<sha>.tar.xz`. Unpack into
`~/.steam/root/compatibilitytools.d/` and restart Steam.

Requires rootless podman (or docker): on NixOS set
`virtualisation.podman.enable = true;`. First build downloads the SDK
image and compiles everything (hours); later runs reuse `work/` and
ccache.

```sh
nix develop   # dev shell for running scripts/*.sh individually
```

## Layout

```
config/    component repos/branches + remote patch sources
scripts/   one step per file, tar.sh orchestrates
patches/   local patches per component (wine fixes -> patches/wine)
fixes/     gamefixes (*.py overlays for protonfixes)
nix/       dev shell + nix run app
work/      checkouts, build tree, ccache (gitignored)
out/       finished tarballs (gitignored)
```

## Customizing

- Pin or change a component: edit `config/sources.conf`
  (`branch=auto` picks the newest versioned branch).
- Add a wine fix: drop `NNNN-name.patch` into `patches/wine/`
  (numbers above the cachyos patches, e.g. `0101-`).
- Add a game fix: drop `<appid>.py` into `fixes/gamefixes/`.
- Refresh the CachyOS fork patches (new cachyos release, or Valve moved
  past them): run `scripts/extract-fork-patches.sh` and commit the
  regenerated `patches/*/000N-cachyos-*.patch`.

Everything is picked up automatically on the next `nix run .#tar`.
