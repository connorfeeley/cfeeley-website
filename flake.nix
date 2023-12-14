{
  description = "Flake for personal website.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    devshell.url = "github:numtide/devshell";

    flake-compat = { url = "github:edolstra/flake-compat"; flake = false; };

    # flake-parts and friends.
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-root.url = "github:srid/flake-root";
    treefmt-nix = { url = "github:numtide/treefmt-nix"; inputs.nixpkgs.follows = "nixpkgs"; };
  };

  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } ({ withSystem, moduleWithSystem, flake-parts-lib, ... }:
      {
        debug = true;
        systems = nixpkgs.lib.systems.flakeExposed;
        imports = [
          inputs.treefmt-nix.flakeModule
          inputs.flake-root.flakeModule
          inputs.devshell.flakeModule
        ];

        flake = { };

        perSystem = { self', config, pkgs, ... }:
          let
            emacsForPublish = ((pkgs.emacsPackagesFor pkgs.emacs29).emacsWithPackages (
              epkgs: with epkgs; [ esxml htmlize webfeeder dash projectile yaml-mode ox-rss ]
            ));
          in
          {
            packages.default = pkgs.callPackage ./nix/cfeeley-website/default.nix { inherit emacsForPublish; publishUrl = null; };

            devshells.default = {  };

            # Treefmt configuration.
            treefmt.config = {
              inherit (config.flake-root) projectRootFile;
              package = pkgs.treefmt;
              programs.nixpkgs-fmt.enable = true;
            };
          };
      });
}
