-- moor/dashboard.lua
-- The todo dashboard: a singleton float over the vault's tasks, grouped by
-- source note. Two scopes share the buffer, the keymaps, and the render:
--   "all"     — every open task in the vault (done ones are hidden)
--   "project" — the current project's todo file, done tasks shown struck-through
-- Always renders from a fresh scan — the vault syncs externally, so cached
-- state would lie.

local M = {}

local ns = vim.api.nvim_create_namespace("moor.dashboard")

-- Struck-through done tasks: one combined group (strikethrough + Comment's
-- color) so a single extmark carries the whole style — stacked marks merge
-- unreliably. `default` lets colorschemes and users override; re-defined on
-- ColorScheme because `:hi clear` wipes it.
local function define_hl()
  local comment = vim.api.nvim_get_hl(0, { name = "Comment", link = false })
  vim.api.nvim_set_hl(0, "MoorDone", { default = true, strikethrough = true, fg = comment.fg })
  vim.api.nvim_set_hl(0, "MoorDoneMark", { default = true, link = "Comment" })
  -- Deliberately empty: open checkboxes render as plain text. Define the
  -- group yourself (colorscheme or config) to give them a color.
  vim.api.nvim_set_hl(0, "MoorTodoMark", { default = true })
  vim.api.nvim_set_hl(0, "MoorLink", { default = true, link = "Underlined" })
end
define_hl()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("MoorDashboardHl", { clear = true }),
  callback = define_hl,
})

---@type integer|nil singleton buffer
local state_buf = nil
---@type table<integer, MoorTodoItem> lnum → item for the current render
local entries = {}
---@type "all"|"project"
local scope = "all"

local function opts()
  return require("moor").options
end

-- ── Render ───────────────────────────────────────────────────────────────────

--- Display form of task text: [[wikilink]] brackets stripped, alias shown
--- when present. Returns the byte ranges of the link labels for highlighting.
--- View-only — items keep the raw line for compare-before-write toggling.
---@param text string
---@return string display, [integer, integer][] link_ranges
local function display_text(text)
  local acc = ""
  local ranges = {}
  local pos = 1
  while true do
    local s, e, inner = text:find("%[%[([^%]]-)%]%]", pos)
    if not s then
      return acc .. text:sub(pos), ranges
    end
    acc = acc .. text:sub(pos, s - 1)
    local label = inner:match("^[^|]*|%s*(.-)%s*$") or inner -- [[Title|alias]] shows the alias
    ranges[#ranges + 1] = { #acc, #acc + #label }
    acc = acc .. label
    pos = e + 1
  end
end

---@return MoorTodoItem[]
local function collect()
  local todo = require("moor.todo")
  if scope == "project" then
    return todo.collect({ paths = { todo.file() }, include_done = true })
  end
  return todo.collect_open()
end

---@param buf integer
local function render(buf)
  local vault = require("moor.vault")
  local tasks = require("moor.tasks")
  local items = collect()

  entries = {}
  local lines = {}
  local marks = {} -- { lnum(0-based), col, end_col, hl_group }
  local last_path = nil

  for _, item in ipairs(items) do
    if item.path ~= last_path then
      if last_path then
        lines[#lines + 1] = ""
      end
      local open_count = 0
      for _, it in ipairs(items) do
        open_count = open_count + ((it.path == item.path and tasks.is_open(it.task)) and 1 or 0)
      end
      local header = (" %s (%d)"):format(vault.relative(item.path), open_count)
      lines[#lines + 1] = header
      marks[#marks + 1] = { #lines - 1, 0, #header, "Title" }
      last_path = item.path
    end
    local open = tasks.is_open(item.task)
    -- icons = false shows the raw markdown brackets; states beyond open/done
    -- (e.g. "-") always fall back to them.
    local icons = opts().dashboard.icons
    if type(icons) ~= "table" then
      icons = { open = "[ ]", done = "[x]" }
    end
    local icon = open and icons.open or (item.task.state == "x" and icons.done or ("[" .. item.task.state .. "]"))
    local prefix = "   " .. icon .. " "
    local text, link_ranges = display_text(item.task.text)
    local row = prefix .. text
    lines[#lines + 1] = row
    entries[#lines] = item
    marks[#marks + 1] = { #lines - 1, 3, #prefix - 1, open and "MoorTodoMark" or "MoorDoneMark" }
    if not open then
      -- Done rows stay uniformly struck and dimmed; no link accents on top.
      marks[#marks + 1] = { #lines - 1, #prefix, #row, "MoorDone" }
    else
      for _, range in ipairs(link_ranges) do
        marks[#marks + 1] = { #lines - 1, #prefix + range[1], #prefix + range[2], "MoorLink" }
      end
      local ref_start = text:find("`[^`]-:%d+`%s*$")
      if ref_start then
        marks[#marks + 1] = { #lines - 1, #prefix + ref_start - 1, #row, "Comment" }
      end
    end
  end
  if #lines == 0 then
    lines = { "", scope == "project" and "   no todos in this project yet" or "   no open todos — go sail ⛵" }
  end

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, m in ipairs(marks) do
    vim.hl.range(buf, ns, m[4], { m[1], m[2] }, { m[1], m[3] })
  end
end

local function refresh()
  if state_buf and vim.api.nvim_buf_is_valid(state_buf) then
    render(state_buf)
  end
end

-- ── Item actions ─────────────────────────────────────────────────────────────

---@return MoorTodoItem|nil
local function item_under_cursor()
  return entries[vim.api.nvim_win_get_cursor(0)[1]]
end

local function jump_to_note()
  local item = item_under_cursor()
  if not item then
    return
  end
  vim.api.nvim_win_close(0, true)
  vim.cmd.edit(vim.fn.fnameescape(item.path))
  vim.api.nvim_win_set_cursor(0, { math.min(item.lnum, vim.api.nvim_buf_line_count(0)), 0 })
end

local function jump_to_context()
  local item = item_under_cursor()
  if not (item and item.task.context) then
    return
  end
  vim.api.nvim_win_close(0, true)
  require("moor.context").jump(item.task.context)
end

--- Toggle the task under the cursor. Public so toggle keybinds that work in
--- ordinary buffers (require("moor").toggle_todo()) also work in here.
--- In "all" scope the completed item disappears; in "project" scope it stays,
--- struck through — toggle again to reopen it.
function M.toggle_current()
  local item = item_under_cursor()
  if not item then
    vim.notify("moor: no todo on this line", vim.log.levels.INFO)
    return
  end
  if not require("moor.todo").toggle_at(item) then
    vim.notify("moor: note changed on disk — rescanning", vim.log.levels.WARN)
  end
  refresh()
end

-- ── Open ─────────────────────────────────────────────────────────────────────

---@return string
local function title()
  if scope == "project" then
    return " todo: " .. require("moor.project").identity() .. " "
  end
  return opts().dashboard.window.title
end

--- Key-hint footer for the float border, built from the configured maps so it
--- never lies. Lives in the border, so it stays pinned to the window bottom.
---@return [string, string][] chunks
local function footer()
  local maps = opts().dashboard.maps
  local hints = {}
  for _, hint in ipairs({
    { maps.toggle, "toggle" },
    { maps.jump, "note" },
    { maps.jump_context, "code" },
    { maps.refresh, "refresh" },
    { maps.close, "close" },
  }) do
    if hint[1] then
      hints[#hints + 1] = ("%s %s"):format(hint[1], hint[2])
    end
  end
  return { { " " .. table.concat(hints, " · ") .. " ", "Comment" } }
end

--- Open (or focus) the dashboard.
---@param open_opts? {scope?: "all"|"project"}
function M.open(open_opts)
  scope = (open_opts and open_opts.scope) or "all"

  local buf
  if state_buf and vim.api.nvim_buf_is_valid(state_buf) then
    buf = state_buf
  else
    buf = vim.api.nvim_create_buf(false, true)
    state_buf = buf
    vim.api.nvim_buf_set_name(buf, "moor://dashboard")
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = "moor-dashboard"

    local maps = opts().dashboard.maps
    local function bmap(lhs, fn, desc)
      if lhs then
        vim.keymap.set("n", lhs, fn, { buffer = buf, desc = "moor: " .. desc })
      end
    end
    bmap(maps.jump, jump_to_note, "jump to note")
    bmap(maps.jump_context, jump_to_context, "jump to code context")
    bmap(maps.toggle, M.toggle_current, "toggle todo")
    bmap(maps.refresh, refresh, "refresh")
    bmap(maps.close, function()
      vim.api.nvim_win_close(0, true)
    end, "close dashboard")

    -- Catch edits that happened while you were away (phone sync, other splits).
    vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, { buffer = buf, callback = refresh })
    vim.api.nvim_create_autocmd("BufWipeout", {
      buffer = buf,
      callback = function()
        state_buf = nil
        entries = {}
      end,
    })
  end

  -- Focus the existing window (re-scoping it) or open a fresh float.
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == buf then
      vim.api.nvim_set_current_win(win)
      vim.api.nvim_win_set_config(win, { title = title(), title_pos = "center" })
      render(buf)
      return
    end
  end

  local w = opts().dashboard.window
  local width = w.width > 1 and math.floor(w.width) or math.floor(vim.o.columns * w.width)
  local height = w.height > 1 and math.floor(w.height) or math.floor(vim.o.lines * w.height)
  local config = {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    border = w.border,
    title = title(),
    title_pos = "center",
    style = "minimal", -- no number column, signcolumn, or inherited decorations
  }
  if w.border ~= "none" then
    config.footer = footer()
    config.footer_pos = "center"
  end
  vim.api.nvim_open_win(buf, true, config)
  vim.wo.cursorline = true -- style=minimal clears it; the view wants it back
  render(buf)
end

return M
