-- moor/project.lua
-- Project identity: the name that keys the per-project todo file.
-- Git root basename when inside a repo, else the cwd basename.

local M = {}

--- Identify the current project.
---@param cwd? string  Injectable for tests; defaults to the current directory.
---@return string name, string root
function M.identity(cwd)
  cwd = cwd or assert(vim.uv.cwd())
  local root = vim.fs.root(cwd, ".git") or cwd
  return vim.fs.basename(root), root
end

return M
