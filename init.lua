require("_cfg.treesitter")

local plugins = require("nln").plugins

plugins["vim-fugitive"] = {
	lazy = true,
	cmd = "G",
}

require("lazy").setup(plugins:for_lazy(), {
	performance = {
		rtp = {
			disabled_plugins = {
				"netrwPlugin",
				"tohtml",
				"tutor",
			},
		},
	},
})
