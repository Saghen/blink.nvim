{
  description = "Set of simple, performant neovim plugins";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    fenix.url = "github:nix-community/fenix";
    fenix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ flake-parts, nixpkgs, fenix, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "i686-linux"
        "x86_64-darwin"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      perSystem = { config, self', inputs', pkgs, system, lib, ... }: {
        # define the packages provided by this flake
        packages = {
          blink-nvim = pkgs.vimUtils.buildVimPlugin {
            pname = "blink-nvim";
            version = "2024-11-11";
            src = ./.;

            meta = {
              description = "Set of simple, performant neovim plugins";
              homepage = "https://github.com/saghen/blink.nvim";
              license = lib.licenses.mit;
              maintainers = with lib.maintainers; [ redxtech ];
            };
          };

          default = self'.packages.blink-nvim;
        };
      };
    };
}
