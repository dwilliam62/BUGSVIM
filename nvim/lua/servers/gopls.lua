-- ================================================================================================
-- TITLE : gopls (Go Language Server) LSP Setup
-- LINKS :
--   > docs   : https://go.dev/gopls
--   > github : https://github.com/golang/tools/tree/master/gopls
-- ================================================================================================

--- @param capabilities table LSP client capabilities (typically from blink-cmp or similar)
--- @return nil
return function(capabilities)
  vim.lsp.config('gopls', {
    cmd = { 'gopls' },
    filetypes = { 'go', 'gomod', 'gowork', 'gotmpl' },
    root_markers = { 'go.work', 'go.mod', '.git' },
    capabilities = capabilities,
    settings = {
      gopls = {
        completeUnimported = true,
        usePlaceholders = true,
        analyses = {
          unusedparams = true,
          unusedwrite = true,
        },
        hints = {
          assignVariableTypes = true,
          compositeLiteralFields = true,
          compositeLiteralTypes = true,
          constantValues = true,
          parameterNames = true,
          rangeVariableTypes = true,
        },
      },
    },
  })
end
