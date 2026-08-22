-- moor/completion.lua
-- Note-title completion inside [[wikilinks]]. A classic completefunc, set
-- buffer-locally on markdown files that live under notes_dir, and popped
-- automatically the moment "[[" is typed. Zero dependencies: <C-x><C-u>
-- summons it manually, native <C-n>/<C-p> navigate.

local M = {}

local function opts()
  return require("moor").options
end

local function enabled()
  return opts().links.completion ~= false
end

-- ── The completefunc ─────────────────────────────────────────────────────────

--- Start column of the link title being typed, or nil when the cursor is not
--- inside an open [[ … (no closing ]] yet).
---@param line string  Text before the cursor
---@return integer|nil byte_col  0-based
local function link_start(line)
  local open = line:match(".*()%[%[")
  if not open then
    return nil
  end
  if line:find("%]%]", open + 1) then
    return nil -- the last [[ is already closed
  end
  return open + 1 -- 0-based col right after "[["
end

---@param findstart integer @param base string
---@return integer|table
function M.completefunc(findstart, base)
  if findstart == 1 then
    local line = vim.api.nvim_get_current_line():sub(1, vim.api.nvim_win_get_cursor(0)[2])
    return link_start(line) or -3
  end
  local vault = require("moor.vault")
  -- Close the link with exactly the brackets still missing: autopair plugins
  -- often insert "]" or "]]" right after the cursor when "[[" is typed, and
  -- appending blindly would double them up.
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local following = line:sub(col + 1, col + 2)
  local suffix = "]]"
  if following:sub(1, 2) == "]]" then
    suffix = ""
  elseif following:sub(1, 1) == "]" then
    suffix = "]"
  end
  local needle = base:lower()
  local items = {}
  for _, path in ipairs(vault.list_notes()) do
    local title = vault.title_for_path(path)
    if needle == "" or title:lower():find(needle, 1, true) then
      items[#items + 1] = {
        word = title .. suffix,
        abbr = title,
        menu = vault.relative(path),
        icase = 1,
      }
    end
  end
  return items
end

-- ── Attachment ───────────────────────────────────────────────────────────────

---@param buf integer @return boolean
local function in_vault(buf)
  local path = vim.api.nvim_buf_get_name(buf)
  if path == "" then
    return false
  end
  local root = require("moor.vault").root()
  -- resolve() both sides: on macOS /var is a symlink to /private/var.
  return vim.fs.relpath(root, path) ~= nil or vim.fs.relpath(vim.fn.resolve(root), vim.fn.resolve(path)) ~= nil
end

---@param buf integer
local function attach_buffer(buf)
  vim.bo[buf].completefunc = "v:lua.require'moor.completion'.completefunc"
  -- Pop the menu the moment "[[" lands, so links complete without a chord.
  vim.api.nvim_create_autocmd("InsertCharPre", {
    buffer = buf,
    group = vim.api.nvim_create_augroup("MoorCompletionBuf" .. buf, { clear = true }),
    callback = function()
      if vim.v.char == "[" and vim.api.nvim_get_current_line():sub(vim.fn.col(".") - 1, vim.fn.col(".") - 1) == "[" then
        vim.schedule(function()
          if vim.api.nvim_get_mode().mode == "i" then
            vim.api.nvim_feedkeys(vim.keycode("<C-x><C-u>"), "n", false)
          end
        end)
      end
    end,
  })
end

--- Register the FileType autocmd (called by setup(); cleared and re-created
--- so repeated setup never stacks duplicates).
function M.attach()
  local group = vim.api.nvim_create_augroup("MoorCompletion", { clear = true })
  if not enabled() then
    return
  end
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "markdown",
    callback = function(ev)
      -- Vault notes and moor's own capture floats; other markdown is not ours.
      if in_vault(ev.buf) or vim.api.nvim_buf_get_name(ev.buf):match("^moor://capture/") then
        attach_buffer(ev.buf)
      end
    end,
  })
end

return M
