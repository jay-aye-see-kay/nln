print("hi from root init.lua")
require("_cfg.treesitter")

local plugins = require("nln").plugins
vim.print(plugins)

plugins["vim-fugitive"] = {
	lazy = true,
	cmd = "G",
}

require("lazy").setup(plugins:for_lazy())
