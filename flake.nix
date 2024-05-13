{
  description = "A configured Neovim flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }@inputs:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ ];
        };

        utils = (import ./utils.nix) { inherit pkgs; };

        customConfig = pkgs.neovimUtils.makeNeovimConfig {
          withPython3 = true;
          extraPython3Packages = p: [ p.debugpy ];
          withNodeJs = true;
          customRC = ''
            lua << EOF
              vim.opt.rtp:prepend("${./config}")
              vim.opt.packpath = vim.opt.rtp:get()
              require("_cfg")
            EOF
          '';
          plugins = with pkgs.vimPlugins; [
            vim-fugitive
          ];
        };

        # Extra packages made available to nvim but not the system
        # system packages take precedence over these
        extraPkgsPath = pkgs.lib.makeBinPath (with pkgs; [
          nil # nix lsp
          sumneko-lua-language-server
        ]);

        # depsTable = fpkgs.writeText "included.lua" ''return ${(import ../utils).luaTablePrinter allPluginDeps}'';

        makeNeovim =
          { extraPkgsPath ? ""
          , extraPython3Packages ? (p: [ ])
          , plugins ? [ ]
          , withPython3 ? true
          , withNodeJs ? true
            # todo: add appname (for cfg dir) here
            # some way to pass in lua files in here too (or just default to this dir)
          }:
          let
            cfg = pkgs.neovimUtils.makeNeovimConfig {
              inherit
                extraPkgsPath extraPython3Packages plugins withNodeJs withPython3;
              customRC = ''
                lua << EOF
                  vim.opt.rtp:prepend("${./config}")
                  vim.opt.packpath = vim.opt.rtp:get()
                  require("_cfg")
                  vim.g.from_nixpkgs = ${utils.luaListPrinter plugins}
                EOF
              '';
            };
          in
          pkgs.wrapNeovimUnstable pkgs.neovim-unwrapped (cfg // {
            wrapperArgs = customConfig.wrapperArgs ++ [ "--suffix" "PATH" ":" extraPkgsPath ];
          });

        mainNeovim = makeNeovim {
          plugins = with pkgs.vimPlugins; [
            vim-fugitive
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
