local plugins = require("nln").plugins

require("cfg.colors")
require("cfg.mini")
require("cfg.treesitter")

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
