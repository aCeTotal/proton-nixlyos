# Dev shell: tools for running/debugging the build pipeline by hand.
# The heavy compilation itself happens inside the Steam Runtime SDK
# container that Proton's build system pulls via podman.
{ pkgs }:

pkgs.mkShell {
  packages = with pkgs; [
    git
    curl
    jq
    gnumake
    podman
    ccache
    python3
    gnutar
    xz
    zstd
  ];

  shellHook = ''
    echo "proton-nixlyos dev shell"
    echo "  nix run .#tar   -> fetch latest sources, build, produce tarball in ./out"
    echo "  scripts/tar.sh  -> same thing, run directly for debugging"
  '';
}
