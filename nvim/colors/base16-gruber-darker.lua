--[[
┏┓┳┓┳┳┳┓┏┓┳┓  ┳┓┏┓┳┓┓┏┓┏┓┳┓
┃┓┣┫┃┃┣┫┣ ┣┫━━┃┃┣┫┣┫┃┫ ┣ ┣┫
┗┛┛┗┗┛┻┛┗┛┛┗  ┻┛┛┗┛┗┛┗┛┗┛┛┗
]]

-- Setup config & colors for base16 nvim

-- Make sure the file exist
local colors = {
	base00 = "#181818",
	base01 = "#282828",
	base02 = "#453d41",
	base03 = "#52494e",
	base04 = "#e4e4ef",
	base05 = "#ffffff",
	base06 = "#f4f4ff",
	base07 = "#f5f5f5",
	base08 = "#ff4f58",
	base09 = "#f43841",
	base0A = "#ffdd33",
	base0B = "#73c936",
	base0C = "#96a6c8",
	base0D = "#9e95c7",
	base0E = "#95a99f",
	base0F = "#cc8c3c",
}

-- Setup config
require("base16-colorscheme").with_config({
	telescope = false,
	indentblankline = false,
	cmp = false,
	notify = false,
})

-- Setup colors
require("base16-colorscheme").setup(colors)

-- Set colorscheme name so plugins recognize it
vim.g.colors_name = "base16-wal"
