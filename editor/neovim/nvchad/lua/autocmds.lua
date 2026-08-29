require("nvchad.autocmds")

local group = vim.api.nvim_create_augroup("PlatformctlNvChad", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = { "gitcommit", "markdown", "text" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
  end,
})
