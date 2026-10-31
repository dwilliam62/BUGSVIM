-- ================================================================================================
-- TITLE : zls (Zig Language Server) LSP Setup
-- LINKS :
--   > docs   : https://zigtools.org/zls/
--   > github : https://github.com/zigtools/zls
-- ================================================================================================

--- @param capabilities table LSP client capabilities (typically from blink-cmp or similar)
--- @return nil
return function(capabilities)
  vim.lsp.config('zls', {
    cmd = { 'zls' },
    filetypes = { 'zig', 'zir' },
    root_markers = { 'build.zig', 'build.zig.zon', 'zls.json', '.git' },
    capabilities = capabilities,
    settings = {
      zls = {
        -- Keep diagnostics in zls and formatting in conform ('zig fmt'), so the
        -- two do not fight over the same buffer.
        enable_build_on_save = false,
        enable_autofix = false,
        semantic_tokens = 'partial',
        inlay_hints = {
          enable = true,
        },
      },
    },
  })
end
