return {
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}

      local tools = {
        "actionlint",
        "ansible-lint",
        "hadolint",
        "shellcheck",
        "shfmt",
        "stylua",
        "yamllint",
      }

      vim.list_extend(opts.ensure_installed, tools)
    end,
  },

  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>a", group = "architecture" },
        { "<leader>o", group = "operations" },
      },
    },
  },

  {
    "folke/todo-comments.nvim",
    opts = {},
  },

  {
    "sindrets/diffview.nvim",
    cmd = {
      "DiffviewOpen",
      "DiffviewFileHistory",
      "DiffviewClose",
    },
  },
}
