---@type ChadrcConfig
local M = {}

M.base46 = {
  -- Closest built-in NvChad palette to the workstation's Tokyo Night family.
  theme = "tokyonight",
  transparency = false,
}

M.ui = {
  statusline = {
    theme = "default",
  },
  tabufline = {
    lazyload = true,
  },
}

return M
