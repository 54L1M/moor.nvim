-- moor/vault.lua
-- All notes_dir filesystem access: scan, read, write, resolve titles.
-- No caching by design — the vault syncs externally (iCloud, git, phone),
-- so every operation re-reads. A few hundred notes scan in milliseconds.
-- Reads never error: evicted iCloud placeholders and mid-sync races yield nil.

local M = {}

local function opts()
  return require("moor").options
end

-- ── Paths ────────────────────────────────────────────────────────────────────

---@return string root  Absolute, expanded notes_dir
function M.root()
  return (vim.fs.normalize(vim.fn.expand(opts().notes_dir)))
end

--- Path relative to the vault root (for display), or unchanged if outside it.
---@param path string
---@return string
function M.relative(path)
  return vim.fs.relpath(M.root(), path) or path
end

---@param path string @return string title  Basename sans .md (ZenNotes canonical)
function M.title_for_path(path)
  return (vim.fs.basename(path):gsub("%.md$", ""))
end

-- ── Scan ─────────────────────────────────────────────────────────────────────

--- Recursively list every markdown note under notes_dir, honoring opts().ignore.
---@return string[] paths  Absolute paths
function M.list_notes()
  local root = M.root()
  local ignored = {}
  for _, name in ipairs(opts().ignore) do
    ignored[name] = true
  end
  local paths = {}
  local ok, iter = pcall(vim.fs.dir, root, {
    depth = math.huge,
    skip = function(dir)
      return not ignored[vim.fs.basename(dir)]
    end,
  })
  if not ok then
    return paths
  end
  for name, kind in iter do
    if kind == "file" and name:sub(-3) == ".md" and not ignored[vim.fs.basename(vim.fs.dirname(name))] then
      paths[#paths + 1] = vim.fs.joinpath(root, name)
    end
  end
  table.sort(paths)
  return paths
end

--- Find the note whose filename matches `title` (case-insensitive), anywhere
--- in the tree. ZenNotes/Obsidian resolve [[Title]] by filename, so do we.
---@param title string
---@return string|nil path
function M.path_for_title(title)
  local want = (title .. ".md"):lower()
  for _, path in ipairs(M.list_notes()) do
    if vim.fs.basename(path):lower() == want then
      return path
    end
  end
  return nil
end

-- ── Read / write ─────────────────────────────────────────────────────────────

--- Read a note's lines. Prefers a loaded buffer (fresher than disk mid-edit);
--- returns nil for missing/unreadable files instead of erroring.
---@param path string
---@return string[]|nil lines
function M.read_lines(path)
  local buf = vim.fn.bufnr(path)
  if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
    return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  end
  local ok, fd = pcall(io.open, path, "r")
  if not ok or not fd then
    return nil
  end
  local content = fd:read("*a")
  fd:close()
  local lines = vim.split(content, "\n", { plain = true })
  if lines[#lines] == "" then
    table.remove(lines) -- drop the trailing-newline artifact
  end
  return lines
end

--- Overwrite a note with `lines`, creating parent directories as needed.
---@param path string
---@param lines string[]
---@return boolean ok
function M.write_lines(path, lines)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local ok, fd = pcall(io.open, path, "w")
  if not ok or not fd then
    return false
  end
  fd:write(table.concat(lines, "\n"), "\n")
  fd:close()
  return true
end

--- Append `lines` to a note. A new file gets a "# Title" first line so it
--- renders with a proper title in ZenNotes/Obsidian.
---@param path string
---@param lines string[]
---@return boolean ok
function M.append_lines(path, lines)
  local existing = M.read_lines(path)
  if not existing then
    existing = { "# " .. M.title_for_path(path), "" }
  end
  vim.list_extend(existing, lines)
  local buf = vim.fn.bufnr(path)
  if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
    -- Keep a loaded buffer authoritative: update it and flush to disk.
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, existing)
    return M.flush_buffer(buf)
  end
  return M.write_lines(path, existing)
end

--- Write a loaded buffer back to its file via :write, keeping nvim's
--- change-tracking (mtime, 'modified') consistent.
---@param buf integer
---@return boolean ok
function M.flush_buffer(buf)
  return pcall(vim.api.nvim_buf_call, buf, function()
    vim.cmd("silent keepalt write!")
  end)
end

-- ── Create ───────────────────────────────────────────────────────────────────

--- Create an empty note titled `title` in opts().links.new_note_dir.
---@param title string
---@return string path
function M.create_note(title)
  local dir = vim.fs.joinpath(M.root(), opts().links.new_note_dir)
  local path = vim.fs.joinpath(dir, title .. ".md")
  M.write_lines(path, { "# " .. title, "" })
  return path
end

return M
