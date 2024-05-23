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
            luaPath = "${./.}";
            LuaConfig = pkgs.stdenv.mkDerivation {
              name = "nixCats-special-rtp-entry-LuaConfig";
              builder = pkgs.writeText "builder.sh" /* bash */ ''
                source $stdenv/setup
                mkdir -p $out
                cp -r ${luaPath}/* $out/
              '';
            };

            cfg = pkgs.neovimUtils.makeNeovimConfig {
              inherit
                extraPkgsPath extraPython3Packages plugins withNodeJs withPython3;
              customRC = /* vim */ ''
                lua << EOF
                  vim.opt.rtp:prepend("${LuaConfig}")
                EOF

                let configdir = "${LuaConfig}"
                if filereadable(configdir . "/init.lua")
                  execute "source " . configdir . "/init.lua"
                elseif filereadable(configdir . "/init.vim")
                  execute "source " . configdir . "/init.vim"
                endif
              '';
            };
          in
          pkgs.wrapNeovimUnstable pkgs.neovim-unwrapped (cfg // {
            wrapperArgs = cfg.wrapperArgs ++ [ "--suffix" "PATH" ":" extraPkgsPath ];
          });

        mainNeovim = makeNeovim {
          plugins = with pkgs.vimPlugins; [
            vim-fugitive
          ];
          extraPkgsPath = pkgs.lib.makeBinPath (with pkgs; [
            # nil # nix lsp
            # sumneko-lua-language-server
          ]);
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
