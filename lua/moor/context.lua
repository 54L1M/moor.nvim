-- moor/context.lua
-- Code-context references: moor a todo to a file:line and jump back later.
-- Format: a trailing inline code span, project-root-relative —
--   - [ ] handle nil palette · `lua/oshen/palette.lua:41`
-- Renders as plain monospace on ZenNotes/Obsidian/phone; no fragile URI links.

local M = {}

-- ── Pure format/parse ────────────────────────────────────────────────────────

--- Extract a trailing code-span reference from task text.
---@param text string
---@return {path: string, lnum: number}|nil
function M.extract(text)
  local path, lnum = text:match("`([^`]-):(%d+)`%s*$")
  if not path or path == "" then
    return nil
  end
  return { path = path, lnum = tonumber(lnum) }
end

-- ── Current location ─────────────────────────────────────────────────────────

--- Reference for the cursor position in `win` (default: current window),
--- with the path made relative to the project root when possible.
---@param win? integer
---@return {path: string, lnum: number}|nil  nil for unnamed buffers
function M.current(win)
  win = win or 0
  local buf = vim.api.nvim_win_get_buf(win)
  local path = vim.api.nvim_buf_get_name(buf)
  if path == "" then
    return nil
  end
  local _, root = require("moor.project").identity()
  local rel = vim.fs.relpath(root, path)
  return {
    path = rel or path,
    lnum = vim.api.nvim_win_get_cursor(win)[1],
  }
end

-- ── Jump ─────────────────────────────────────────────────────────────────────

--- Open the referenced file at its line. Relative paths resolve against the
--- project root, then the cwd. Notifies with the raw ref when nothing exists.
---@param ref {path: string, lnum: number}
---@return boolean ok
function M.jump(ref)
  local candidates = { ref.path }
  if not vim.startswith(ref.path, "/") then
    local _, root = require("moor.project").identity()
    candidates = { vim.fs.joinpath(root, ref.path), vim.fs.joinpath(vim.uv.cwd(), ref.path) }
  end
  for _, path in ipairs(candidates) do
    if vim.uv.fs_stat(path) then
      vim.cmd.edit(vim.fn.fnameescape(path))
      local last = vim.api.nvim_buf_line_count(0)
      vim.api.nvim_win_set_cursor(0, { math.min(ref.lnum, last), 0 })
      return true
    end
  end
  vim.notify(("moor: cannot resolve `%s:%d` from here"):format(ref.path, ref.lnum), vim.log.levels.WARN)
  return false
end

return M
