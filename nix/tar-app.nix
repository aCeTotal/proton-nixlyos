# `nix run .#tar` entry point.
# Code and config are read from the flake source (always in sync with the
# repo, nix re-evaluates on every run). Mutable state (checkouts, build,
# output) lives under the invoking directory: ./work and ./out.
{ pkgs, self }:

let
  script = pkgs.writeShellApplication {
    name = "proton-nixlyos-tar";
    runtimeInputs = with pkgs; [
      git
      curl
      jq
      gnumake
      podman
      python3
      gnutar
      gzip
      xz
      zstd
      gnused
      gawk
      coreutils
      findutils
      gnupatch
    ];
    text = ''
      export PN_ROOT=${self}
      exec bash ${self}/scripts/tar.sh "$@"
    '';
  };
in
{
  type = "app";
  program = "${script}/bin/proton-nixlyos-tar";
}
