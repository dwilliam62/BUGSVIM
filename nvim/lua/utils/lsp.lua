-- ================================================================================================
-- TITLE: Neovim lsp config
-- ABOUT: sets the base for lsp configuration
-- ================================================================================================

local M = {}

M.on_attach = function(event)
  local client = vim.lsp.get_client_by_id(event.data.client_id)
  if not client then
    return
  end

  local bufnr = event.buf
  local keymap = vim.keymap.set
  local function opts(desc)
    return { noremap = true, silent = true, buffer = bufnr, desc = '[LSP]:' .. desc }
  end

  -- stylua: ignore start
  -- Native LSP Keymaps
  keymap("n", "<leader>gd", vim.lsp.buf.definition, opts("Go to definition"))
  keymap("n", "<leader>gS", function() vim.cmd("vsplit") vim.lsp.buf.definition() end, opts("Go to definition (split)"))
  keymap("n", "<leader>gD", vim.lsp.buf.declaration, opts("Go to declaration"))
  keymap("n", "<leader>ca", vim.lsp.buf.code_action, opts("Code action"))
  keymap("n", "<leader>rn", vim.lsp.buf.rename, opts("Rename symbol"))
  keymap("n", "<leader>D", vim.diagnostic.open_float, opts("Line diagnostics"))
  keymap("n", "<leader>C", function() vim.diagnostic.open_float(nil, { scope = "cursor" }) end, opts("Cursor diagnostics"))
  keymap("n", "<leader>[d", function () vim.diagnostic.jump({count = -1}) end, opts("Previous diagnostic"))
  keymap("n", "<leader>]d", function () vim.diagnostic.jump({count = 1}) end, opts("Next diagnostic"))
  keymap("n", "K", vim.lsp.buf.hover, opts("Hover documentation"))
  -- stylua: ignore end

  -- Organize Imports (if supported)
  if client:supports_method('textDocument/codeAction', bufnr) then
    keymap('n', '<leader>oi', function()
      vim.lsp.buf.code_action {
        context = { only = { 'source.organizeImports' }, diagnostics = {} },
        apply = true,
        bufnr = bufnr,
      }
      vim.defer_fn(function()
        vim.lsp.buf.format { bufnr = bufnr }
      end, 50)
    end, opts 'Organize imports')
  end

  -- Incremental renaming with inc-rename.nvim
  keymap('n', '<leader>crn', function()
    local inc_rename = require 'inc_rename'
    return ':' .. inc_rename.config.cmd_name .. ' ' .. vim.fn.expand '<cword>'
  end, {
    expr = true,
    desc = '[LSP]: Rename (inc-rename.nvim)',
  })
end

return M
