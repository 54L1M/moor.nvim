-- moor/links.lua
-- Wikilinks: follow [[Title]] under the cursor (creating missing notes on
-- request) and list backlinks to the current note. Titles resolve by filename,
-- the ZenNotes/Obsidian convention. Pure synchronous scan, no index — the
-- vault is small and syncs externally, so an index would only go stale.

local M = {}

-- ── Link detection ────────────────────────────────────────────────────────────

--- Strip alias/heading decorations: "Title|alias" / "Title#heading" → "Title".
---@param inner string @return string
local function bare_title(inner)
  return vim.trim(inner:match("^([^|#]+)") or inner)
end

--- The [[link]] spanning the cursor column, if any.
---@return string|nil title
function M.link_at_cursor()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1 -- 1-based
  local from = 1
  while true do
    local s, e, inner = line:find("%[%[([^%]]-)%]%]", from)
    if not s then
      return nil
    end
    if col >= s and col <= e then
      return bare_title(inner)
    end
    from = e + 1
  end
end

-- ── Follow ───────────────────────────────────────────────────────────────────

--- Open the note the cursor's [[link]] points to; offer to create it if missing.
function M.follow()
  local title = M.link_at_cursor()
  if not title then
    vim.notify("moor: no [[link]] under cursor", vim.log.levels.INFO)
    return
  end
  local vault = require("moor.vault")
  local path = vault.path_for_title(title)
  if path then
    vim.cmd.edit(vim.fn.fnameescape(path))
    return
  end
  vim.ui.select({ "Yes", "No" }, { prompt = ("Create note '%s'?"):format(title) }, function(choice)
    if choice == "Yes" then
      vim.cmd.edit(vim.fn.fnameescape(vault.create_note(title)))
    end
  end)
end

-- ── Backlinks ────────────────────────────────────────────────────────────────

---@class MoorBacklink
---@field path string  Absolute path of the linking note
---@field lnum number
---@field line string  The line containing the link

--- Every line in the vault linking to `title` (case-insensitive; matches
--- [[Title]], [[Title|alias]] and [[Title#heading]] forms).
---@param title string
---@return MoorBacklink[]
function M.backlinks_to(title)
  local vault = require("moor.vault")
  local want = title:lower()
  local results = {}
  for _, path in ipairs(vault.list_notes()) do
    if vault.title_for_path(path):lower() ~= want then
      local lines = vault.read_lines(path)
      if lines then
        for lnum, line in ipairs(lines) do
          if line:find("[[", 1, true) then -- cheap fast-path before pattern work
            for inner in line:gmatch("%[%[([^%]]-)%]%]") do
              if bare_title(inner):lower() == want then
                results[#results + 1] = { path = path, lnum = lnum, line = line }
                break
              end
            end
          end
        end
      end
    end
  end
  return results
end

--- Pick a backlink to the current note and jump to it.
function M.show_backlinks()
  local vault = require("moor.vault")
  local name = vim.api.nvim_buf_get_name(0)
  if not name:find("%.md$") then
    vim.notify("moor: not in a markdown note", vim.log.levels.INFO)
    return
  end
  local title = vault.title_for_path(name)
  local backlinks = M.backlinks_to(title)
  if #backlinks == 0 then
    vim.notify(("moor: no backlinks to [[%s]]"):format(title), vim.log.levels.INFO)
    return
  end
  require("moor.picker").select(backlinks, {
    prompt = ("backlinks to [[%s]]"):format(title),
    format = function(bl)
      return ("%s:%d  %s"):format(vault.relative(bl.path), bl.lnum, vim.trim(bl.line))
    end,
  }, function(bl)
    if bl then
      vim.cmd.edit(vim.fn.fnameescape(bl.path))
      vim.api.nvim_win_set_cursor(0, { math.min(bl.lnum, vim.api.nvim_buf_line_count(0)), 0 })
    end
  end)
end

return M
