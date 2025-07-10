{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
    zig = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      zig,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        zig-pkg = zig.packages.${system}."0.14.0";
      in
      {
        formatter = pkgs.nixfmt-rfc-style;

        packages.default = pkgs.stdenv.mkDerivation {
          name = "htmlentities.zig-build";

          src = ./.;

          nativeBuildInputs = [
            zig-pkg
          ];

          buildPhase = ''
            export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig"
            zig build test
            touch $out
          '';

          dontInstall = true;
        };

        devShells.default = pkgs.mkShell {
          name = "htmlentities.zig";

          packages = [
            zig-pkg
            pkgs.zls
          ];
        };
      }
    );

}
