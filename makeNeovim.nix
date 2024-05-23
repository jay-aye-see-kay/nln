{ pkgs, ... }:

{ extraPackages ? [ ]
, extraPython3Packages ? (p: [ ])
, plugins ? [ ]
, withPython3 ? true
, withNodeJs ? true
, luaPath ? "${./.}"
, nvimAppName ? ""
}:
let
  utils = import ./utils.nix { inherit pkgs; };

  #
  # user config as a plugin
  #
  userConfig = pkgs.stdenv.mkDerivation {
    name = "nln-user-config";
    builder = pkgs.writeText "builder.sh" /* bash */ ''
      source $stdenv/setup
      mkdir -p $out
      cp -r ${luaPath}/* $out/
    '';
  };

  #
  # convert a list of plugins into a dict we can modify, then pass to lazy.nvim
  #
  pluginsForConfig = builtins.foldl'
    (acc: elem: { "${elem.pname}" = { }; } // acc)
    { }
    plugins;
  pluginDirs = builtins.foldl'
    (acc: elem: { "${elem.pname}" = "${elem}"; } // acc)
    { }
    plugins;

  #
  # this file is how we pass build info (like paths) to lua config
  #
  generatedLuaFile = pkgs.writeText "generated.lua" /* lua */ ''
    -- DO NOT EDIT: this file was generated and will be overwritted
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
          local lazy_spec = vim.tbl_extend("force", p_cfg, { dir = pluginDirs[p_name], name = p_name })
          table.insert(result, lazy_spec)
        end
      end
      return result
    end
    return M
  '';

  #
  # plugin containing paths etc generated at build time
  #
  nlnPlugin = pkgs.stdenv.mkDerivation {
    name = "nln-plugin";
    builder = pkgs.writeText "builder" /* bash */ ''
      source $stdenv/setup
      mkdir -p $out/lua/nln
      cat ${generatedLuaFile} > $out/lua/nln/init.lua
    '';
  };

  #
  # cfg for wrapNeovimUnstable
  #
  cfg = pkgs.neovimUtils.makeNeovimConfig {
    inherit extraPython3Packages withNodeJs withPython3;
    plugins = [ pkgs.vimPlugins.lazy-nvim ];
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

  #
  # modify cfg before it gets to wrapNeovimUnstable
  #
  extraCfg = {
    wrapperArgs = cfg.wrapperArgs ++
      [ "--suffix" "PATH" ":" (pkgs.lib.makeBinPath extraPackages) ];
  };

  #
  # finally a derivation we can build
  #
  nvimPkg = pkgs.wrapNeovimUnstable pkgs.neovim-unwrapped (cfg // extraCfg);
in
if nvimAppName == "" then
  nvimPkg
else
# wrap and rename binary if given custom name
# see: https://wiki.nixos.org/wiki/Nix_Cookbook#Wrapping_packages
  pkgs.runCommand "nvim-renamed-to-${nvimAppName}"
  { buildInputs = [ pkgs.makeWrapper ]; }
    ''
      # Link every top-level folder from nvimPkg to our new target (except /bin)
      mkdir $out
      ln -s ${nvimPkg}/* $out
      rm $out/bin
      # bin should just contain our wrapped + renamed binary
      mkdir $out/bin
      makeWrapper ${nvimPkg}/bin/nvim $out/bin/${nvimAppName} \
        --set NVIM_APPNAME ${nvimAppName}
    ''
