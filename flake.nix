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

            # user config as a plugin
            userConfig = pkgs.stdenv.mkDerivation {
              name = "nln-user-config";
              builder = pkgs.writeText "builder.sh" /* bash */ ''
                source $stdenv/setup
                mkdir -p $out
                cp -r ${luaPath}/* $out/
              '';
            };

            # convert a list of plugins into a dict we can modify, then pass to lazy.nvim
            pluginsForConfig = builtins.foldl'
              (acc: elem: { "${elem.pname}" = { }; } // acc)
              { }
              plugins;
            pluginDirs = builtins.foldl'
              (acc: elem: { "${elem.pname}" = "${elem}"; } // acc)
              { }
              plugins;

            # this file is how we pass build info (like paths) to lua config
            generatedLuaFile = pkgs.writeText "generated.lua" /* lua */ ''
              local M = {}
              -- keep private so can't be modified, map pnames to store path
              pluginDirs = ${utils.luaTablePrinter pluginDirs}
              -- mutable list of plugins to collect config
              M.plugins = ${utils.luaTablePrinter pluginsForConfig}
              -- method to call after configuring to convert to list for lazy.nvim
              function M.plugins:for_lazy()
                local result = {}
                for p_name, p_cfg in pairs(self) do
                  if type(p_cfg) ~= "function" then
                    local lazy_spec = vim.tbl_extend("force", p_cfg, { dir = pluginDirs[p_name] })
                    table.insert(result, lazy_spec)
                  end
                end
                return result
              end
              return M
            '';

            # plugin containing paths etc generated at build time
            nlnPlugin = pkgs.stdenv.mkDerivation {
              name = "nln-plugin";
              builder = pkgs.writeText "builder" /* bash */ ''
                source $stdenv/setup
                mkdir -p $out/lua/nln
                cat ${generatedLuaFile} > $out/lua/nln/init.lua
              '';
            };

            cfg = pkgs.neovimUtils.makeNeovimConfig {
              inherit extraPkgsPath extraPython3Packages withNodeJs withPython3;
              plugins = plugins ++ [ pkgs.vimPlugins.lazy-nvim ];
              customRC = /* vim */ ''
                lua << EOF
                  -- Ignore the user lua configuration
                  vim.opt.runtimepath:remove(vim.fn.stdpath("config")) -- ~/.config/nvim
                  vim.opt.runtimepath:remove(vim.fn.stdpath("config") .. "/after") -- ~/.config/nvim/after
                  vim.opt.runtimepath:remove(vim.fn.stdpath("data") .. "/site") -- ~/.local/share/nvim/site

                  vim.opt.rtp:prepend("${userConfig}")
                  vim.opt.rtp:prepend("${nlnPlugin}")

                  if vim.fn.filereadable("${userConfig}/init.lua") then
                    vim.cmd("source ${userConfig}/init.lua")
                  end
                EOF
              '';
            };
          in
          pkgs.wrapNeovimUnstable pkgs.neovim-unwrapped (cfg // {
            wrapperArgs = cfg.wrapperArgs ++ [ "--suffix" "PATH" ":" extraPkgsPath ];
          });

        mainNeovim = makeNeovim {
          plugins = with pkgs.vimPlugins; [
            vim-fugitive
            zoxide-vim
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
