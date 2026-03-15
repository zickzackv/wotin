{
  description = "Wotin - Work Time Tracker";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    systems = ["x86_64-linux" "aarch64-darwin"];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
  in {
    packages = forAllSystems (system: let
      pkgs = import nixpkgs {inherit system;};
    in {
      default = pkgs.stdenv.mkDerivation {
        pname = "wotin";
        version = "0.1.0";
        src = ./src;

        nativeBuildInputs = [pkgs.odin];
        buildInputs = [pkgs.sqlite];

        buildPhase = ''
          odin build . -out:wotin -o:speed
        '';

        installPhase = ''
          install -Dm755 wotin $out/bin/wotin
        '';
      };
    });

    devShells = forAllSystems (system: let
      pkgs = import nixpkgs {inherit system;};
    in {
      default = pkgs.mkShell {
        buildInputs = with pkgs; [odin sqlite watson];
        shellHook = ''
          export LD_LIBRARY_PATH="${pkgs.sqlite.out}/lib:$LD_LIBRARY_PATH"
        '';
      };
    });
  };
}
