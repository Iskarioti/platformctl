return {
	{
		"nvim-treesitter/nvim-treesitter",
		-- nvim-treesitter's default branch was switched to "main", a full
		-- rewrite with a different API (no more .configs module/setup()) -
		-- this config uses the pre-rewrite API, so pin to "master" (the
		-- legacy-compatible branch upstream still maintains) rather than
		-- rewriting the config to the new API. Found live: the plugin
		-- installed successfully but crashed on startup with "module
		-- 'nvim-treesitter.configs' not found" until this was added.
		branch = "master",
		event = { "BufReadPost", "BufNewFile" },
		cmd = { "TSInstall", "TSBufEnable", "TSBufDisable", "TSModuleInfo" },
		build = ":TSUpdate",
		dependencies = {
			"apple/pkl-neovim",
			"windwp/nvim-ts-autotag",
			--"vrischmann/tree-sitter-templ",
		},
		opts = function()
			return require("plugins.configs.treesitter")
		end,
		config = function(_, opts)
			require("nvim-treesitter.configs").setup(opts)
		end,
	},
	{
		"windwp/nvim-ts-autotag",
		event = { "BufReadPost", "BufNewFile" },
		config = function(_, opts)
			require("nvim-ts-autotag").setup({
				opts = {
					-- Defaults
					enable_close = true,      -- Auto close tags
					enable_rename = true,     -- Auto rename pairs of tags
					enable_close_on_slash = false, -- Auto close on trailing </
				},
				-- Also override individual filetype configs, these take priority.
				-- Empty by default, useful if one of the "opts" global settings
				-- doesn't work well in a specific filetype
				aliases = {
					["template"] = "html",
				},
			})
		end,
	},
}
