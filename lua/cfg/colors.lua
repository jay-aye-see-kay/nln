local h = require("cfg.helpers")

-- extend color scheme
h.autocmd({ "ColorScheme" }, {
	callback = function()
		local copy_color = function(from, to)
			vim.api.nvim_set_hl(0, to, vim.api.nvim_get_hl_by_name(from, true))
		end
		copy_color("DiffAdd", "diffAdded")
		copy_color("DiffDelete", "diffRemoved")
		copy_color("DiffChange", "diffChanged")
	end,
})

vim.api.nvim_set_var("vim_json_syntax_conceal", 0)

vim.o.background = "dark"

-- loaded before lazy.nvim
require("catppuccin").setup({
	term_colors = true,
	integrations = {
		cmp = true,
		gitsigns = true,
		markdown = true,
		mini = true,
		neotree = true,
		noice = true,
		notify = true,
		semantic_tokens = true,
		telescope = true,
		which_key = true,
		-- For more integrations https://github.com/catppuccin/nvim#integrations
	},
	custom_highlights = function(colors)
		return {
			CodeBlockBackground = { bg = colors.surface0 },
			ActiveTerm = { bg = colors.crust },
		}
	end,
})
vim.cmd.colorscheme("catppuccin-macchiato") -- latte, frappe, macchiato, mocha
