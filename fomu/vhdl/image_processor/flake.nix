{
  inputs = {
    nixgl.url = "github:nix-community/nixGL";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = {
    self,
    nixgl,
    nixpkgs,
    rust-overlay,
  }: let
    system = "x86_64-linux";

    pkgs = import nixpkgs {
      inherit system;
      overlays = [
        nixgl.overlay
        rust-overlay.overlays.default
      ];
    };

    rust = pkgs.rust-bin.stable.latest.default;
  in
    with pkgs; {
      devShells.${system}.default = mkShell {
        packages = [
          rust
          nvc
          ghdl
          yosys
          surfer
          nextpnr
          minicom
          yosys-ghdl
          dfu-util
          icestorm

          # swim
          # spade

          pkgs.nixgl.nixGLMesa
        ];

        env = {
          FOMU_REV = "pvt";
          RUST_SRC_PATH = "${rust}/lib/rustlib/src/rust/library";
          LD_LIBRARY_PATH = lib.makeLibraryPath [
            libusb1
          ];
        };
      };
    };
}
