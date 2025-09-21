--[[
┏┳┓┏┓┓┏┓┓┏┏┓┳┓┳┏┓┓┏┏┳┓  ┳┓┳┏┓┓┏┏┳┓
 ┃ ┃┃┃┫ ┗┫┃┃┃┃┃┃┓┣┫ ┃ ━━┃┃┃┃┓┣┫ ┃ 
 ┻ ┗┛┛┗┛┗┛┗┛┛┗┻┗┛┛┗ ┻   ┛┗┻┗┛┛┗ ┻ 
                                  
--]]
-- Setup config & colors for base16 nvim

-- Make sure the file exist
local colors = {
  base00 = "#1a1b26",
  base01 = "#292e42",
  base02 = "#414868",
  base03 = "#565f89",
  base04 = "#a9b1d6",
  base05 = "#c0caf5",
  base06 = "#cbccd1",
  base07 = "#d5d6db",
  base08 = "#f7768e",
  base09 = "#ff007c",
  base0A = "#e0af68",
  base0B = "#9ece6a",
  base0C = "#7dcfff",
  base0D = "#7aa2f7",
  base0E = "#bb9af7",
  base0F = "#1abc9c",
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
