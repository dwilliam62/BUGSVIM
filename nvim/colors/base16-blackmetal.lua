--[[
┳┓┓ ┏┓┏┓┓┏┓  ┳┳┓┏┓┏┳┓┏┓┓ 
┣┫┃ ┣┫┃ ┃┫ ━━┃┃┃┣  ┃ ┣┫┃ 
┻┛┗┛┛┗┗┛┛┗┛  ┛ ┗┗┛ ┻ ┛┗┗┛
                         
--]]
-- Setup config & colors for base16 nvim

-- Make sure the file exist
local colors = {
  base00 = '#000000',
  base01 = '#121212',
  base02 = '#222222',
  base03 = '#333333',
  base04 = '#999999',
  base05 = '#c1c1c1',
  base06 = '#999999',
  base07 = '#c1c1c1',
  base08 = '#5f8787',
  base09 = '#aaaaaa',
  base0A = '#a06666',
  base0B = '#dd9999',
  base0C = '#aaaaaa',
  base0D = '#888888',
  base0E = '#999999',
  base0F = '#444444',
}

-- Setup config
require('base16-colorscheme').with_config {
  telescope = false,
  indentblankline = false,
  cmp = false,
  notify = false,
}

-- Setup colors
require('base16-colorscheme').setup(colors)

-- Set colorscheme name so plugins recognize it
vim.g.colors_name = 'base16-wal'
