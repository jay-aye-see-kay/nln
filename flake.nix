{
  description = "A configured Neovim flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ ];
        };
        makeNeovim = import ./makeNeovim.nix { inherit pkgs; };

        mainNeovim = makeNeovim {
          nvimAppName = "test-nvim";

          lazyPlugins = with pkgs.vimPlugins; [
            vim-fugitive
            zoxide-vim
            catppuccin-nvim
            # this isn't working as expected, lazy loads the plugin later on, but the grammars don't get loaded in
            (nvim-treesitter.withPlugins (_: nvim-treesitter.allGrammars))
          ];

          extraPackages = with pkgs; [
            nil # nix lsp
            sumneko-lua-language-server
          ];
        };

      in
      rec {
        packages.nvim = mainNeovim;
        defaultPackage = packages.nvim;
        apps.nvim = { type = "app"; program = "${defaultPackage}/bin/nvim"; };
        apps.default = apps.nvim;
        overlays.default = final: prev: { neovim = defaultPackage; };
      }
    );
}
