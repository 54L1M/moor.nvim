-- moor/project.lua
-- Project identity: the name that keys the per-project todo file.
-- Git root basename when inside a repo, else the cwd basename.

local M = {}

--- Identify the current project.
---@param cwd? string  Injectable for tests; defaults to the current directory.
---@return string name, string root
function M.identity(cwd)
  -- uv.cwd() fails (nil) when the directory was deleted underneath the
  -- session; getcwd() still knows the nominal path, so fall through to it.
  -- vim.fs.root can still assert internally in that state — treat any
  -- failure as "no repo found" rather than crashing the caller.
  cwd = cwd or vim.uv.cwd() or vim.fn.getcwd()
  local ok, root = pcall(vim.fs.root, cwd, ".git")
  root = (ok and root) or cwd
  return vim.fs.basename(root), root
end

return M
