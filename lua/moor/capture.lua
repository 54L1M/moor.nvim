-- moor/capture.lua
-- The capture float: a scratch acwrite buffer over your code. `:w` routes the
-- contents into the vault and closes the window — one gesture, back to code.
-- <C-p> promotes the same buffer to a split for longer writing; <C-c> abandons.

local M = {}

local function opts()
  return require("moor").options
end

-- ── Save routing ─────────────────────────────────────────────────────────────

---@param buf integer
---@return boolean ok
local function save(buf)
  local vault = require("moor.vault")
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local mode = vim.b[buf].moor_mode
  local ok, target

  if mode == "todo" then
    local tasks = require("moor.tasks")
    local due = require("moor.due")
    local context = vim.b[buf].moor_context
    local out = {}
    for _, line in ipairs(lines) do
      if vim.trim(line) ~= "" then
        line = due.expand(line)
        local task = tasks.parse(line)
        if not task then
          -- Prose becomes an open task.
          out[#out + 1] = tasks.format(line, context)
        elseif context and not task.context then
          -- Hand-typed "- [ ] …" lines still deserve the stashed mooring.
          out[#out + 1] = ("%s · `%s:%d`"):format(line:gsub("%s+$", ""), context.path, context.lnum)
        else
          out[#out + 1] = line
        end
      end
    end
    if #out == 0 then
      return false
    end
    target = require("moor.todo").file()
    ok = vault.append_lines(target, out)
  else
    while lines[#lines] and vim.trim(lines[#lines]) == "" do
      table.remove(lines)
    end
    if #lines == 0 then
      return false
    end
    local stamp = opts().capture.timestamp
    if stamp then
      -- A string is an os.date() format; `true` means the default one.
      local fmt = type(stamp) == "string" and stamp or "## %Y-%m-%d %H:%M"
      table.insert(lines, 1, os.date(fmt))
    end
    table.insert(lines, "")
    target = vim.fs.joinpath(vault.root(), os.date(opts().capture.note_file))
    ok = vault.append_lines(target, lines)
  end

  if ok then
    vim.bo[buf].modified = false
    vim.notify("moor: captured → " .. vault.relative(target))
  end
  return ok
end

-- ── Window plumbing ──────────────────────────────────────────────────────────

---@param dim number @param total integer @return integer
local function cells(dim, total)
  return dim > 1 and math.floor(dim) or math.floor(total * dim)
end

---@param buf integer @param title string @return integer win
local function open_float(buf, title)
  local w = opts().capture.window
  local width = cells(w.width, vim.o.columns)
  local height = cells(w.height, vim.o.lines)
  return vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    border = w.border,
    title = title,
    title_pos = "center",
    style = "minimal", -- no number column or inherited decorations while jotting
  })
end

--- Reopen the capture buffer in a real split; everything (content, undo
--- history, BufWriteCmd, stashed context) survives because it is the same buffer.
---@param buf integer @param win integer
local function promote(buf, win)
  vim.bo[buf].bufhidden = "hide"
  if vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
  vim.cmd("botright vsplit")
  vim.api.nvim_win_set_buf(0, buf)
end

-- ── Public ───────────────────────────────────────────────────────────────────

--- Open the capture float.
---@param capture_opts? {mode?: "note"|"todo", context?: boolean}
function M.open(capture_opts)
  capture_opts = capture_opts or {}
  local mode = capture_opts.mode or "note"

  -- Grab the code location before any window changes hands.
  local context = capture_opts.context and require("moor.context").current() or nil

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "moor://capture/" .. mode .. "/" .. buf)
  vim.bo[buf].buftype = "acwrite"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "markdown"
  vim.b[buf].moor_mode = mode
  vim.b[buf].moor_context = context

  local win = open_float(buf, opts().capture.window.title .. mode .. " ")

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function()
      if save(buf) then
        -- :w is the "done" gesture — wipe the capture wherever it lives.
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
          end
        end)
      end
    end,
  })

  local maps = opts().capture.maps
  if maps.promote then
    vim.keymap.set({ "n", "i" }, maps.promote, function()
      promote(buf, win)
    end, { buffer = buf, desc = "moor: promote capture to split" })
  end
  if maps.abort then
    vim.keymap.set({ "n", "i" }, maps.abort, function()
      vim.api.nvim_buf_delete(buf, { force = true })
    end, { buffer = buf, desc = "moor: abandon capture" })
  end

  vim.cmd.startinsert()
  return buf, win
end

return M
