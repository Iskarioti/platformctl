local map = vim.keymap.set

map("n", "<leader>w", "<cmd>w<cr>", { desc = "Save" })
map("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit All" })

map("n", "<C-h>", "<C-w>h", { desc = "Window Left" })
map("n", "<C-j>", "<C-w>j", { desc = "Window Down" })
map("n", "<C-k>", "<C-w>k", { desc = "Window Up" })
map("n", "<C-l>", "<C-w>l", { desc = "Window Right" })

-- Architecture / operational notes are often Markdown.
map("n", "<leader>on", function()
  vim.cmd("edit " .. vim.fn.expand("~/src/knowledge"))
end, { desc = "Open Knowledge Workspace" })

-- Never add a force-push shortcut. Git governance remains outside the editor.
