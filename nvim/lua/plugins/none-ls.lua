return {
  'nvimtools/none-ls.nvim',
  event = { 'BufReadPre', 'BufNewFile' },
  dependencies = {
    'nvimtools/none-ls-extras.nvim',
    'jayp0521/mason-null-ls.nvim', -- ensure dependencies are installed
  },
  config = function()
    local null_ls = require 'null-ls'
    local formatting = null_ls.builtins.formatting -- to setup formatters
    local diagnostics = null_ls.builtins.diagnostics -- to setup linters

    -- Formatters & linters for mason to install
    require('mason-null-ls').setup {
      ensure_installed = {
        'prettier', -- ts/js, markdown, html, css, formatter
        'clang-format', -- C and cpp code formatter
        'eslint_d', -- ts/js linter
        'shfmt', -- Shell formatter
        'checkmake', -- linter for Makefiles
        'google-java-format', -- Fomatter for java
        'gofumpt', -- Formatter for go
        'goimports-reviser', -- Import organizer for go
        'golangci-lint', -- Linter for go
        -- 'stylua', -- lua formatter; Already installed via Mason
      },
      automatic_installation = true,
    }

    local sources = {
      require 'none-ls.code_actions.eslint_d',
      require 'none-ls.diagnostics.eslint_d',
      diagnostics.checkmake,
      diagnostics.golangci_lint,
      formatting.gofumpt,
      formatting.clang_format,
      formatting.goimports_reviser,
      formatting.prettier.with { filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact', 'html', 'css', 'json', 'yaml', 'markdown' } },
      formatting.stylua,
      formatting.shfmt.with { args = { '-i', '4' } },
    }

    local augroup = vim.api.nvim_create_augroup('LspFormatting', {})
    null_ls.setup {
      -- debug = true, -- Enable debug mode. Inspect logs with :NullLsLog.
      sources = sources,
      -- you can reuse a shared lspconfig on_attach callback here
      on_attach = function(client, bufnr)
        if client:supports_method 'textDocument/formatting' then
          vim.api.nvim_clear_autocmds { group = augroup, buffer = bufnr }
          vim.api.nvim_create_autocmd('BufWritePre', {
            group = augroup,
            buffer = bufnr,
            callback = function()
              vim.lsp.buf.format { async = true }
            end,
          })
        end
      end,
    }
  end,
}
