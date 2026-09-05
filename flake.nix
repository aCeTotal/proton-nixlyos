{
  description = "proton-nixlyos - bleeding-edge Proton tarball builder in the style of proton-cachyos";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems (system:
        f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAll (pkgs: {
        default = import ./nix/devshell.nix { inherit pkgs; };
      });

      apps = forAll (pkgs: rec {
        tar = import ./nix/tar-app.nix { inherit pkgs self; };
        default = tar;
      });
    };
}
