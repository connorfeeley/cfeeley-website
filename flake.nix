{
  description = "Flake for personal website.";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.devshell.url = "github:numtide/devshell";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  inputs.flake-compat = { url = "github:edolstra/flake-compat"; flake = false; };

  outputs = { self, nixpkgs, flake-utils, devshell, ... }:
    flake-utils.lib.eachDefaultSystem (system: {
      packages.default = let pkgs = import nixpkgs { inherit system; }; in with pkgs;
        stdenv.mkDerivation {
          src = ./.;
          name = "cfeeley-website";
          buildInputs = [ emacs rsync ];
          buildPhase = ''
            mkdir -p $out
            emacs -Q --batch -l publish.el --funcall dw/publish
            cp -r resources/* public/
            cp -r public/* $out
          '';
        };
      devShells.default =
        let
          pkgs = import nixpkgs {
            inherit system;

            overlays = [ devshell.overlays.default ];
          };
        in
        pkgs.devshell.mkShell {
          imports = [ (pkgs.devshell.importTOML ./devshell.toml) ];
        };
    });
}
