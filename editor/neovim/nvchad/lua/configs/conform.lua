local options = {
  formatters_by_ft = {
    lua = { "stylua" },
    sh = { "shfmt" },
    bash = { "shfmt" },
    python = { "ruff_format" },
    terraform = { "terraform_fmt" },
    hcl = { "terraform_fmt" },
  },
  format_on_save = {
    timeout_ms = 1000,
    lsp_fallback = true,
  },
}

return options
