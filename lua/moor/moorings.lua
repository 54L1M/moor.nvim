-- moor/moorings.lua
-- The reverse direction of a moored todo: the code line shows the anchor.
-- Open tasks in the project todo file whose `path:lnum` reference points at a
-- buffer's file get a sign on that line, and a jump takes you from the code
-- to the todo. Signs are re-read from the todo file on every refresh — no
-- cache, same as everything else in moor.

local M = {}

local ns = vim.api.nvim_create_namespace("moor.moorings")

local function opts()
  return require("moor").options
end

local function enabled()
  return type(opts().moorings) == "table"
end

--- Project-root-relative form of an absolute path, tolerating the macOS
--- /var → /private/var symlink split between cwd and resolved buffer names.
---@param root string @param path string @return string|nil
local function rel_to(root, path)
  return vim.fs.relpath(root, path) or vim.fs.relpath(vim.fn.resolve(root), vim.fn.resolve(path))
end

-- ── Collection ───────────────────────────────────────────────────────────────

--- Open project todos moored to `path`.
---@param path string  Absolute file path
---@return MoorTodoItem[]
function M.collect_for(path)
  local todo = require("moor.todo")
  local _, root = require("moor.project").identity()
  local rel = rel_to(root, path)
  if not rel then
    return {}
  end
  local items = {}
  for _, item in ipairs(todo.collect({ paths = { todo.file() } })) do
    if item.task.context and item.task.context.path == rel then
      items[#items + 1] = item
    end
  end
  return items
end

-- ── Signs ────────────────────────────────────────────────────────────────────

--- Re-place the mooring signs for one buffer.
---@param buf? integer
function M.refresh(buf)
  buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  if not enabled() then
    return
  end
  local path = vim.api.nvim_buf_get_name(buf)
  if path == "" or vim.bo[buf].buftype ~= "" then
    return
  end
  -- A dead cwd or unreadable vault must never turn sign placement into an
  -- error — no moorings is the correct degraded result.
  local ok, items = pcall(M.collect_for, path)
  if not ok then
    return
  end
  local last = vim.api.nvim_buf_line_count(buf)
  for _, item in ipairs(items) do
    local lnum = item.task.context.lnum
    if lnum >= 1 and lnum <= last then
      vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, 0, {
        sign_text = opts().moorings.sign,
        sign_hl_group = "MoorAnchor",
      })
    end
  end
end

--- Refresh every buffer currently shown in a window (used after moor itself
--- changes the todo file, so new anchors appear without re-entering).
function M.refresh_visible()
  local seen = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if not seen[buf] then
      seen[buf] = true
      M.refresh(buf)
    end
  end
end

-- ── Jump ─────────────────────────────────────────────────────────────────────

---@param item MoorTodoItem
local function goto_todo(item)
  vim.cmd.edit(vim.fn.fnameescape(item.path))
  vim.api.nvim_win_set_cursor(0, { math.min(item.lnum, vim.api.nvim_buf_line_count(0)), 0 })
end

--- Jump from the code to its moored todo: the current line's mooring when
--- there is one, otherwise a pick from all moorings in this file.
function M.jump()
  local path = vim.api.nvim_buf_get_name(0)
  local items = path ~= "" and M.collect_for(path) or {}
  if #items == 0 then
    vim.notify("moor: no todos moored to this file", vim.log.levels.INFO)
    return
  end
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local on_line = vim.tbl_filter(function(item)
    return item.task.context.lnum == lnum
  end, items)
  local candidates = #on_line > 0 and on_line or items
  if #candidates == 1 then
    goto_todo(candidates[1])
    return
  end
  require("moor.picker").select(candidates, {
    prompt = "moorings in this file",
    format = function(item)
      return (":%d  %s"):format(item.task.context.lnum, item.task.text)
    end,
  }, function(item)
    if item then
      goto_todo(item)
    end
  end)
end

-- ── Wiring ───────────────────────────────────────────────────────────────────

--- Register the autocmds (called by setup(); cleared and re-registered on
--- each call so repeated setup never stacks duplicates).
function M.attach()
  local group = vim.api.nvim_create_augroup("MoorMoorings", { clear = true })
  if not enabled() then
    return
  end
  vim.api.nvim_set_hl(0, "MoorAnchor", { default = true, link = "Special" })
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufEnter" }, {
    group = group,
    callback = function(ev)
      M.refresh(ev.buf)
    end,
  })
  M.refresh_visible()
end

return M
