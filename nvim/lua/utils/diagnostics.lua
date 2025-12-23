-- ================================================================================================
-- TITLE: NeoVim diagnostics config
-- ABOUT: sets some diagnostics config for neovim
-- ================================================================================================

local M = {}

local icons = require 'config.icons'

M.setup = function()
  vim.diagnostic.config {
    underline = true,
    update_in_insert = false,
    virtual_text = {
      spacing = 4,
      source = 'if_many',
      prefix = ' 󰣤 ',
    },
    severity_sort = true,
    signs = {
      text = {
        [vim.diagnostic.severity.ERROR] = icons.diagnostics.Error,
        [vim.diagnostic.severity.WARN] = icons.diagnostics.Warn,
        [vim.diagnostic.severity.INFO] = icons.diagnostics.Info,
        [vim.diagnostic.severity.HINT] = icons.diagnostics.Hint,
      },
    },
  }
end

return M
