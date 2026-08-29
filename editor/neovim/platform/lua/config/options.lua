local opt = vim.opt

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Predictable, security-conscious project loading.
opt.exrc = false
opt.modeline = false

opt.number = true
opt.relativenumber = true
opt.mouse = "a"
opt.wrap = false
opt.linebreak = true
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.signcolumn = "yes"

opt.splitright = true
opt.splitbelow = true

opt.ignorecase = true
opt.smartcase = true

opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2

opt.undofile = true
opt.swapfile = false
opt.backup = false
opt.writebackup = false

opt.updatetime = 200
opt.timeoutlen = 300
opt.termguicolors = true
opt.confirm = true
opt.cursorline = true

opt.completeopt = { "menu", "menuone", "noselect" }

-- Keep project-local runtimes out of the WSL host where possible.
vim.g.lazyvim_python_lsp = "pyright"
vim.g.lazyvim_python_ruff = "ruff"
vim.g.lazyvim_ts_lsp = "vtsls"
