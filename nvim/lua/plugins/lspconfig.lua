return {
  'neovim/nvim-lspconfig',
  event = { 'BufReadPre', 'BufNewFile' },
  cmd = { 'LspInfo', 'LspInstall', 'LspUninstall' },
  dependencies = {
    -- Automatically install LSPs and related tools to stdpath for Neovim
    { 'mason-org/mason.nvim', config = true }, -- NOTE: Must be loaded before dependants
    -- mason-lspconfig:
    -- - Bridges the gap between LSP config names (e.g. "lua_ls") and actual Mason package names (e.g. "lua-language-server").
    -- - Used here only to allow specifying language servers by their LSP name (like "lua_ls") in `ensure_installed`.
    -- - It does not auto-configure servers — we use vim.lsp.config() + vim.lsp.enable() explicitly for full control.
    'mason-org/mason-lspconfig.nvim',
    -- mason-tool-installer:
    -- - Installs LSPs, linters, formatters, etc. by their Mason package name.
    -- - We use it to ensure all desired tools are present.
    -- - The `ensure_installed` list works with mason-lspconfig to resolve LSP names like "lua_ls".
    'WhoIsSethDaniel/mason-tool-installer.nvim',
  },
  config = function()
    -- Load icons
    local icons = require 'config.icons'

    -- Setup diagnostics config

    local default_diagnostic_config = {
      underline = true,
      signs = {
        text = {
          [vim.diagnostic.severity.ERROR] = icons.diagnostics.BoldError,
          [vim.diagnostic.severity.WARN] = icons.diagnostics.BoldWarning,
          [vim.diagnostic.severity.HINT] = icons.diagnostics.BoldHint,
          [vim.diagnostic.severity.INFO] = icons.diagnostics.BoldInformation,
        },
      },
      virtual_text = {
        spacing = 4,
        source = 'if_many',
        prefix = '▪',
      },
      update_in_insert = true,
      severity_sort = true,
      float = {
        focusable = true,
        style = 'minimal',
        border = 'single',
        source = 'always',
        header = '',
        prefix = '',
      },
    }

    -- Now pass the diagnostics config table
    vim.diagnostic.config(default_diagnostic_config)

    -- Create autocmd for LspAttach
    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('nvim-lsp-attach', { clear = true }),
      callback = function(event)
        -- Add the lightbulb
        require('utils.lightbulb').attach_lightbulb(event.buf, event.data.client_id)

        -- Create a function that lets us more easily define mappings specific
        -- for LSP related items. It sets the mode, buffer and description for us each time.
        local map = function(keys, func, desc, mode, opts)
          mode = mode or 'n'
          opts = vim.tbl_extend('force', {
            buffer = event.buf,
            desc = 'LSP: ' .. desc,
          }, opts or {})
          vim.keymap.set(mode, keys, func, opts)
        end

        -- Jump to the definition of the word under your cursor.
        map('gd', require('fzf-lua').lsp_definitions, '[G]oto [D]efinition')

        -- Find references for the word under your cursor.
        map('gR', require('fzf-lua').lsp_references, '[G]oto [R]eferences')

        -- Jump to the implementation of the word under your cursor.
        --  Useful when your language has ways of declaring types without an actual implementation.
        map('gI', require('fzf-lua').lsp_implementations, '[G]oto [I]mplementation')

        -- Jump to the type of the word under your cursor.
        --  Useful when you're not sure what type a variable is and you want to see
        --  the definition of its *type*, not where it was *defined*.
        map('<leader>gD', require('fzf-lua').lsp_typedefs, 'Type [D]efinition')

        -- Fuzzy find all the symbols in your current document.
        --  Symbols are things like variables, functions, types, etc.
        map('<leader>gs', require('fzf-lua').lsp_document_symbols, '[D]ocument [S]ymbols')

        -- Fuzzy find all the symbols in your current workspace.
        --  Similar to document symbols, except searches over your entire project.
        map('<leader>Ws', require('fzf-lua').lsp_workspace_symbols, '[W]orkspace [S]ymbols')

        -- Rename the variable under your cursor incrementally
        -- stylua: ignore start
        map('<leader>rn', function() return ':IncRename ' .. vim.fn.expand '<cword>' end, '[I]ncremental [R]ename', 'n', { expr = true })
        -- stylua: ignore end

        -- Execute a code action, usually your cursor needs to be on top of an error
        -- or a suggestion from your LSP for this to activate.
        map('<leader>ca', require('fzf-lua').lsp_code_actions, '[C]ode [A]ction', { 'n', 'x' })

        -- WARN: This is not Goto Definition, this is Goto Declaration.
        --  For example, in C this would take you to the header.
        map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

        -- The following two autocommands are used to highlight references of the
        -- word under your cursor when your cursor rests there for a little while.
        --    See `:help CursorHold` for information about when this is executed
        -- When you move your cursor, the highlights will be cleared (the second autocommand).
        local client = vim.lsp.get_client_by_id(event.data.client_id)
        if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
          local highlight_augroup = vim.api.nvim_create_augroup('nvim-lsp-highlight', { clear = false })
          vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
            buffer = event.buf,
            group = highlight_augroup,
            callback = vim.lsp.buf.document_highlight,
          })

          vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
            buffer = event.buf,
            group = highlight_augroup,
            callback = vim.lsp.buf.clear_references,
          })

          vim.api.nvim_create_autocmd('LspDetach', {
            group = vim.api.nvim_create_augroup('nvim-lsp-detach', { clear = true }),
            callback = function(event2)
              vim.lsp.buf.clear_references()
              vim.api.nvim_clear_autocmds { group = 'nvim-lsp-highlight', buffer = event2.buf }
            end,
          })
        end

        -- The following code creates a keymap to toggle inlay hints in your
        -- code, if the language server you are using supports them
        if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
          map('<leader>th', function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
          end, '[T]oggle Inlay [H]ints')
        end
      end,
    })
    -- LSP servers and clients are able to communicate to each other what features they support.
    --  By default, Neovim doesn't support everything that is in the LSP specification.
    --  When you add blink.cmp, luasnip, etc. Neovim now has *more* capabilities.
    --  So, we create new capabilities with blink.cmp, and then broadcast that to the servers.
    local capabilities = require('blink.cmp').get_lsp_capabilities()

    -- Enable the following language servers
    --
    -- Add any additional override configuration in the following tables. Available keys are:
    -- - cmd (table): Override the default command used to start the server
    -- - filetypes (table): Override the default list of associated filetypes for the server
    -- - capabilities (table): Override fields in capabilities. Can be used to disable certain LSP features.
    -- - settings (table): Override the default settings passed when initializing the server.
    local servers = {
      clangd = {},
      ts_ls = {
        settings = {
          typescript = {
            inlayHints = {
              includeInlayParameterNameHints = 'all',
              includeInlayParameterNameHintsWhenArgumentMatchesName = true,
              includeInlayFunctionParameterTypeHints = true,
              includeInlayVariableTypeHints = true,
              includeInlayPropertyDeclarationTypeHints = true,
              includeInlayFunctionLikeReturnTypeHints = true,
              includeInlayEnumMemberValueHints = true,
            },
          },
          javascript = {
            inlayHints = {
              includeInlayParameterNameHints = 'all',
              includeInlayParameterNameHintsWhenArgumentMatchesName = true,
              includeInlayFunctionParameterTypeHints = true,
              includeInlayVariableTypeHints = true,
              includeInlayPropertyDeclarationTypeHints = true,
              includeInlayFunctionLikeReturnTypeHints = true,
              includeInlayEnumMemberValueHints = true,
            },
          },
        },
      },
      html = { filetypes = { 'html', 'twig', 'hbs' } },
      cssls = {},
      tailwindcss = {},
      emmet_ls = {
        filetypes = { 'html', 'css', 'scss', 'javascriptreact', 'typescriptreact' },
      },
      jsonls = {
        settings = {
          json = {
            validate = { enable = true },
          },
        },
      },
      yamlls = {},
      dockerls = {},
      sqls = {},
      bashls = {},
      gopls = {
        settings = {
          completeUnimported = true,
          usePlaceholders = true,
          analyses = {
            unusedparams = true,
          },
        },
      },
      lua_ls = {
        settings = {
          Lua = {
            completion = {
              callSnippet = 'Replace',
            },
            runtime = { version = 'LuaJIT' },
            workspace = {
              checkThirdParty = false,
              library = vim.api.nvim_get_runtime_file('', true),
            },
            diagnostics = {
              globals = { 'vim' },
              disable = { 'missing-fields' },
            },
            format = {
              enable = false,
            },
          },
        },
      },
    }

    -- Make mason ui a bit better
    require('mason').setup {
      ui = {
        border = vim.g.border_style,
        icons = {
          package_pending = ' ',
          package_installed = ' ',
          package_uninstalled = ' ',
        },
        winhighlight = 'Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:Visual,Search:None',
      },
    }

    -- Ensure the servers and tools above are installed
    local ensure_installed = vim.tbl_keys(servers or {})
    vim.list_extend(ensure_installed, {
      'stylua', -- Used to format Lua code
      'jdtls', -- Java language server
      'java-debug-adapter', -- Java debugging tool
      'java-test', -- Also used for java debugging
      'delve', -- Go debugger
    })
    require('mason-tool-installer').setup { ensure_installed = ensure_installed }

    -- For java don't auto enable java language server
    require('mason-lspconfig').setup {
      automatic_enable = {
        exclude = {
          --needs external plugin
          'jdtls',
        },
      },
    }

    for server, cfg in pairs(servers) do
      -- For each LSP server (cfg), we merge:
      -- 1. A fresh empty table (to avoid mutating capabilities globally)
      -- 2. Your capabilities object with Neovim + cmp features
      -- 3. Any server-specific cfg.capabilities if defined in `servers`
      cfg.capabilities = vim.tbl_deep_extend('force', {}, capabilities, cfg.capabilities or {})

      vim.lsp.config(server, cfg)
      vim.lsp.enable(server)
    end
  end,
}
