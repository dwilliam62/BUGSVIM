-- ================================================================================================
-- TITLE : org.nvim
-- ABOUT : Emacs Org mode for Neovim - outlines, TODOs, agenda, capture, clocking, tables, babel
-- LINKS :
--   > github : https://github.com/xheisenbugx/org.nvim
-- ================================================================================================
-- ENABLED for evaluation on the xorg-vim branch.
--
-- Keep in mind what turning this on does, which is why it stays off on ddubs:
-- org.nvim runs `setup()` at startup (upstream sets lazy = false), so it installs
-- global normal-mode keymaps even when no .org file is ever opened:
--   <leader>oa agenda, <leader>oc capture, <leader>og goto heading,
--   <leader>ols store link, <leader>oxj/oxo/oxq clock, and the Emacs keys
--   <C-c>a / <C-c>c / <C-c>l (which make <C-c> a global prefix).
-- Inside .org buffers it also claims a large set of buffer-local normal-mode keys
-- (fold cycling on <Tab>/<S-Tab>, <leader>o* commands, org text objects).
--
-- Requires Neovim 0.11+; on older versions it notifies and does nothing.
return {
  'xheisenbugx/org.nvim',
  main = 'org',
  enabled = true,
  lazy = false, -- upstream default; heavy modules load on first use
  opts = {
    org_directory = '~/org',
    agenda_files = { '~/org/**/*.org' },
    default_notes_file = '~/org/refile.org',
    -- Keep blink.cmp's insert-mode <Tab> / <S-Tab> / <CR> working inside org
    -- buffers. org.nvim's org_insert defaults claim those keys for table field and
    -- row movement, and its buffer-local maps win over blink.cmp's global ones.
    -- Table editing is still available in normal mode: <leader>oTr/Ti/TR/TI.
    mappings = {
      org_insert = {
        insert_tab = false, -- <Tab>: table next field / heading level
        table_prev_field = false, -- <S-Tab>: table previous field
        table_next_row = false, -- <CR>: table next row
        table_copy_down = false, -- <S-CR>: copy table field down
      },
    },
  },
}
