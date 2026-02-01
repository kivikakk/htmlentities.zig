{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        formatter = pkgs.nixfmt-rfc-style;

        packages.default = pkgs.stdenv.mkDerivation {
          name = "htmlentities.zig-build";

          src = ./.;

          nativeBuildInputs = [
            pkgs.zig
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
            pkgs.zig
            pkgs.zls
          ];
        };
      }
    );

}
