-- ================================================================================================
-- TITLE: Neovim lualine utils
-- ABOUT: defines some utility function for lualine
-- ================================================================================================
local M = {}

-- Lualine components
M.lualine = {}

-- Pretty path
---@param opts? {relative: "cwd"|"root", modified_hl: string?, directory_hl: string?, filename_hl: string?, modified_sign: string?, readonly_icon: string?, length: number?}
function M.lualine.pretty_path(opts)
  opts = vim.tbl_extend('force', {
    relative = 'cwd',
    modified_hl = 'MatchParen',
    directory_hl = '',
    filename_hl = 'Bold',
    modified_sign = '',
    readonly_icon = ' 󰌾 ',
    length = 3,
  }, opts or {})

  return function(self)
    local path = vim.fn.expand '%:p'
    if path == '' then
      return ''
    end

    path = vim.fs.normalize(path)
    local cwd = vim.fs.normalize(vim.fn.getcwd())

    if opts.relative == 'cwd' and path:find(cwd, 1, true) == 1 then
      path = path:sub(#cwd + 2)
    end

    local sep = '/'
    local parts = vim.split(path, '/')

    if opts.length > 0 and #parts > opts.length then
      parts = { parts[1], '…', unpack(parts, #parts - opts.length + 2, #parts) }
    end

    if opts.modified_hl and vim.bo.modified then
      parts[#parts] = parts[#parts] .. opts.modified_sign
      parts[#parts] = M.lualine.format(self, parts[#parts], opts.modified_hl)
    else
      parts[#parts] = M.lualine.format(self, parts[#parts], opts.filename_hl)
    end

    local dir = ''
    if #parts > 1 then
      dir = table.concat({ unpack(parts, 1, #parts - 1) }, sep)
      dir = M.lualine.format(self, dir .. sep, opts.directory_hl)
    end

    local readonly = ''
    if vim.bo.readonly then
      readonly = M.lualine.format(self, opts.readonly_icon, opts.modified_hl)
    end

    return dir .. parts[#parts] .. readonly
  end
end

-- Root dir
---@param opts? {cwd: boolean?, subdirectory: boolean?, parent: boolean?, other: boolean?, icon: string?, color: function?}
function M.lualine.root_dir(opts)
  opts = vim.tbl_extend('force', {
    cwd = false,
    subdirectory = true,
    parent = true,
    other = true,
    icon = '󱉭 ',
    color = function()
      return { fg = Snacks.util.color 'Special' }
    end,
  }, opts or {})

  return {
    function()
      return opts.icon .. vim.fn.fnamemodify(vim.fn.getcwd(), ':t')
    end,
    cond = function()
      return true
    end,
    color = opts.color,
  }
end

-- Pretty date
function M.lualine.pretty_time()
  local hour = tonumber(os.date '%H')
  local clocks = {
    '󱑊 ', -- 12
    '󱐿 ', -- 1
    '󱑀 ', -- 2
    '󱑁 ', -- 3
    '󱑂 ', -- 4
    '󱑃 ', -- 5
    '󱑄 ', -- 6
    '󱑅 ', -- 7
    '󱑆 ', -- 8
    '󱑇 ', -- 9
    '󱑈 ', -- 10
    '󱑉 ', -- 11
  }
  -- Set icons
  local icon = clocks[(hour % 12) + 1]
  return icon .. os.date '%R'
end

-- Format helper for lualine
function M.lualine.format(component, text, hl_group)
  text = text:gsub('%%', '%%%%')
  if not hl_group or hl_group == '' then
    return text
  end

  ---@type table<string, string>
  component.hl_cache = component.hl_cache or {}
  local lualine_hl_group = component.hl_cache[hl_group]

  if not lualine_hl_group then
    local utils = require 'lualine.utils.utils'
    ---@type string[]
    local gui = vim.tbl_filter(function(x)
      return x
    end, {
      utils.extract_highlight_colors(hl_group, 'bold') and 'bold',
      utils.extract_highlight_colors(hl_group, 'italic') and 'italic',
    })

    lualine_hl_group = component:create_hl({
      fg = utils.extract_highlight_colors(hl_group, 'fg'),
      gui = #gui > 0 and table.concat(gui, ',') or nil,
    }, 'LV_' .. hl_group) --[[@as string]]

    component.hl_cache[hl_group] = lualine_hl_group
  end

  return component:format_hl(lualine_hl_group) .. text .. component:get_default_hl()
end

return M
