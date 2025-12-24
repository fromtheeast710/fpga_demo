{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixgl.url = "github:nix-community/nixGL";
    # flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = {
    self,
    nixpkgs,
    nixgl,
  }: let
    system = "x86_64-linux";

    pkgs = import nixpkgs {
      inherit system;
      overlays = [nixgl.overlays.default];
    };

    # TODO: try stack instead?
    package = pkgs.haskellPackages.callCabal2nix "feme" ./. {};
  in {
    packages.${system}.default =
      pkgs.haskell.lib.compose.justStaticExecutables package;

    devShells.${system}.default = pkgs.haskellPackages.shellFor {
      packages = _: [package];

      nativeBuildInputs = [
        pkgs.cabal-install
        pkgs.nixgl.nixGLMesa
      ];
    };
  };
}
