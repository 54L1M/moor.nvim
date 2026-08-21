-- moor/todo.lua
-- Per-project todo file plus the operations every todo feature builds on:
-- append a task, toggle in-buffer, collect open tasks vault-wide, and
-- toggle a task in its source file without corrupting externally-synced notes.

local M = {}

local function opts()
  return require("moor").options
end

-- ── Project todo file ─────────────────────────────────────────────────────────

--- Path of the current project's todo file (created lazily on first append).
---@return string path
function M.file()
  local name = require("moor.project").identity()
  local vault = require("moor.vault")
  return vim.fs.joinpath(vault.root(), opts().todo.dir, name .. ".md")
end

--- Append one open task to the project todo file. Relative due shortcuts
--- (due:tomorrow, due:fri, due:3d) are expanded to absolute dates on the way in.
---@param text string
---@param context? {path: string, lnum: number}
---@return boolean ok
function M.add(text, context)
  if vim.trim(text) == "" then
    return false
  end
  text = require("moor.due").expand(text)
  local vault = require("moor.vault")
  local path = M.file()
  local ok = vault.append_lines(path, { require("moor.tasks").format(text, context) })
  if ok then
    vim.notify("moor: todo → " .. vault.relative(path))
  end
  return ok
end

--- One-motion capture: prompt for text, append. Moored to the cursor position
--- the prompt was opened from by default; pass { context = false } for a
--- plain todo. (Unnamed buffers yield no mooring either way.)
---@param prompt_opts? {context?: boolean}
function M.prompt(prompt_opts)
  prompt_opts = prompt_opts or {}
  local context = prompt_opts.context ~= false and require("moor.context").current() or nil
  vim.ui.input({ prompt = "todo: " }, function(text)
    if text and vim.trim(text) ~= "" then
      M.add(text, context)
    end
  end)
end

-- ── Toggle ───────────────────────────────────────────────────────────────────

--- Toggle the checkbox on the current line of the current buffer. Inside the
--- dashboard (a read-only view) this delegates to its own toggle, so one
--- keybind works everywhere.
function M.toggle_line()
  if vim.bo.filetype == "moor-dashboard" then
    require("moor.dashboard").toggle_current()
    return
  end
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, false)[1]
  local new_line = require("moor.tasks").toggle(line, opts().todo.toggle_states)
  if not new_line then
    vim.notify("moor: no task on this line", vim.log.levels.INFO)
    return
  end
  vim.api.nvim_buf_set_lines(0, lnum - 1, lnum, false, { new_line })
end

-- ── Vault-wide collection ─────────────────────────────────────────────────────

---@class MoorTodoItem
---@field path string    Absolute path of the source note
---@field lnum number    1-indexed line in the source note
---@field line string    The raw line as last read (compare-before-write token)
---@field task MoorTask

--- Collect tasks, in note order.
---@param collect_opts? {paths?: string[], include_done?: boolean}
---  paths: scan only these files (default: the whole vault);
---  include_done: also return non-open tasks (default: open only).
---@return MoorTodoItem[]
function M.collect(collect_opts)
  collect_opts = collect_opts or {}
  local vault = require("moor.vault")
  local tasks = require("moor.tasks")
  local items = {}
  for _, path in ipairs(collect_opts.paths or vault.list_notes()) do
    local lines = vault.read_lines(path)
    if lines then
      for lnum, line in ipairs(lines) do
        local task = tasks.parse(line)
        if task and (collect_opts.include_done or tasks.is_open(task)) then
          items[#items + 1] = { path = path, lnum = lnum, line = line, task = task }
        end
      end
    end
  end
  return items
end

--- Every open task across the vault, in note order.
---@return MoorTodoItem[]
function M.collect_open()
  return M.collect()
end

--- Toggle a collected task in its source note. The source line is re-read and
--- compared against item.line first — external sync (phone, git) may have
--- shifted lines, and a mismatch must never rewrite the wrong one.
---@param item MoorTodoItem
---@return boolean ok  false when the note changed underneath us (rescan needed)
function M.toggle_at(item)
  local vault = require("moor.vault")
  local lines = vault.read_lines(item.path)
  if not lines or lines[item.lnum] ~= item.line then
    return false
  end
  local new_line = require("moor.tasks").toggle(item.line, opts().todo.toggle_states)
  if not new_line then
    return false
  end
  lines[item.lnum] = new_line
  local buf = vim.fn.bufnr(item.path)
  if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
    vim.api.nvim_buf_set_lines(buf, item.lnum - 1, item.lnum, false, { new_line })
    return vault.flush_buffer(buf)
  end
  return vault.write_lines(item.path, lines)
end

return M
