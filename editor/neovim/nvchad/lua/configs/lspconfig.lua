require("nvchad.configs.lspconfig").defaults()

local servers = {
  "ansiblels",
  "bashls",
  "dockerls",
  "docker_compose_language_service",
  "jsonls",
  "lua_ls",
  "marksman",
  "pyright",
  "terraformls",
  "taplo",
  "vtsls",
  "yamlls",
}

vim.lsp.enable(servers)
