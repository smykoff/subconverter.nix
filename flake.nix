{
  description = "subconverter for Nix";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      # Trim this list to the systems that have upstream builds. Note that
      # nixpkgs >= 26.11 no longer supports x86_64-darwin; keep it here and pin
      # nixpkgs to nixpkgs-26.05-darwin when packaging for Intel macOS.
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAll = f: nixpkgs.lib.genAttrs systems (s: f nixpkgs.legacyPackages.${s});
    in {
      packages = forAll (pkgs: rec {
        subconverter = pkgs.callPackage ./package.nix { };
        default = subconverter;
      });

      overlays.default = final: prev: {
        subconverter = final.callPackage ./package.nix { };
      };
    };
}
