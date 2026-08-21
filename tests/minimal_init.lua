-- tests/minimal_init.lua
-- Stripped-down Neovim config used only when running the test suite.
-- Prepends the plugin root and plenary to runtimepath, then bootstraps plenary.
-- Paths are made absolute up front: specs cd() into fixture dirs, and a
-- relative runtimepath would stop resolving moor.* modules after that.

local root = vim.fn.fnamemodify(".", ":p")
vim.opt.runtimepath:prepend(root)
vim.opt.runtimepath:prepend(root .. ".tests/plenary.nvim")

vim.cmd("runtime plugin/plenary.vim")
