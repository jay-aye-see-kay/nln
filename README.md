# NLN

Another idea for tricking neovim, lazy.nvim, and nix into working together. There's plenty of high quality ones that already exist but _for me_ they do too much and become a non-trivial abstraction layer to learn (and debug).

## Principles

- Be a thin as possible layer so debugging issues can usually be done the normal way for whatever isn't working.
- Don't try to hide details of how nix or neovim work, this is for people who know both
- Don't try to work on systems without nix
- All in on lazy.nvim for package management
- Configure neovim as much as possible with lua, nix should only be used to put binaries and files in the right place
- Retain reproducibility, don't read or write files outside of the nix store

## Status

Experimental: sort of works sometimes, I'm not using it yet you shouldn't either.

## How to use

1. Currently the important bits aren't exported so fork the repo to get the `makeNeovim` function
2. Call it to build a package (see `./flake.nix` for an example of use)
3. Lua config files in this dir will be copied into the store and behave as if they were in `~/.config/nvim`
4. Adding plugin specs to lazy is done a bit different than normal as the plugins themselves are provided by nix, see `./init.lua` for an example
5. Use that package as you normally would, i.e. with `nix run. #` or adding to a system flake
