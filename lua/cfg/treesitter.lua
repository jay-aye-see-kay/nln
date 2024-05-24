local plugins = require("nln").plugins

plugins["nvim-treesitter"] = {
	opts = {
		highlight = {
			enable = true,
			additional_vim_regex_highlighting = { "ruby" },
		},
		indent = { enable = true, disable = { "ruby" } },
	},
	config = function(_, opts)
		require("nvim-treesitter.configs").setup(opts)
	end,
}
