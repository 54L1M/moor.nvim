-- moor/init.lua
-- Public API for moor.nvim — notes and todos moored to your code.
--
-- Usage in lazy.nvim:
--   require("moor").setup({ notes_dir = "~/notes" })
--
-- setup() applies the default <leader>n keymaps; disable them all with
-- `keymaps = false`, or one at a time with e.g. `keymaps = { dashboard = false }`.

local M = {}

---@class MoorCaptureWindow
---@field width number   Fraction of columns (or absolute cells when > 1)
---@field height number  Fraction of lines (or absolute cells when > 1)
---@field border string  Border style passed to nvim_open_win
---@field title string   Float title prefix; the capture mode is appended

---@class MoorOptions
---@field notes_dir string  Directory where notes and todos live (a ZenNotes/Obsidian vault works)
---@field ignore string[]   Directory names skipped by every scan

M.defaults = {
  notes_dir = vim.fn.expand("~/notes"),
  ignore = { ".git", ".obsidian", "trash", "archive" },

  capture = {
    -- Destination for plain-note captures, relative to notes_dir. os.date()
    -- tokens are expanded, so "inbox/%Y-%m-%d.md" gives daily notes.
    note_file = "Captures.md",
    -- Heading placed above each note capture, as an os.date() format.
    -- false = raw append; true = this default.
    timestamp = "## %Y-%m-%d %H:%M",
    window = { width = 0.5, height = 0.3, border = "rounded", title = " moor " },
    -- Buffer-local maps inside the capture float (set one to false to disable).
    maps = { promote = "<C-p>", abort = "<C-c>" },
  },

  todo = {
    dir = "todo", -- subdir of notes_dir; the file is "<dir>/<project>.md"
    toggle_states = { " ", "x" }, -- cycle order for toggle (add "-" for cancelled)
  },

  dashboard = {
    window = { width = 0.7, height = 0.7, border = "rounded", title = " open todos " },
    -- How checkboxes render in the dashboard views; the files on disk always
    -- keep plain "- [ ]" markdown. Set icons = false for raw brackets.
    -- `cancelled` styles the "-" state (add it to todo.toggle_states to use it).
    icons = { open = "○", done = "✓", cancelled = "✗" },
    maps = { toggle = "t", jump = "<CR>", jump_context = "gd", sort = "s", refresh = "r", close = "q" },
  },

  links = {
    new_note_dir = "", -- where [[Missing Title]] notes are created, relative to notes_dir
  },

  -- Global normal-mode keymaps, applied by setup(). `keymaps = false` defines
  -- none; a single entry set to false skips just that one; a different lhs
  -- rebinds it.
  keymaps = {
    capture_note = "<leader>nn",
    capture_todo = "<leader>nt",
    capture_todo_context = "<leader>nT",
    add_todo = "<leader>na",
    add_todo_plain = "<leader>nA",
    dashboard = "<leader>nd",
    toggle = "<leader>nx",
    follow_link = "<leader>nf",
    backlinks = "<leader>nb",
    open_todo = "<leader>no",
  },
}

---@type MoorOptions
M.options = vim.deepcopy(M.defaults)

-- What each configurable keymap does; lhs comes from options.keymaps.
local keymap_actions = {
  capture_note = {
    desc = "capture note",
    fn = function()
      M.capture()
    end,
  },
  capture_todo = {
    desc = "capture todo",
    fn = function()
      M.capture({ mode = "todo" })
    end,
  },
  capture_todo_context = {
    desc = "capture moored todo",
    fn = function()
      M.capture({ mode = "todo", context = true })
    end,
  },
  add_todo = {
    desc = "add moored todo (prompt)",
    fn = function()
      M.add_todo()
    end,
  },
  add_todo_plain = {
    desc = "add plain todo (prompt)",
    fn = function()
      M.add_todo({ context = false })
    end,
  },
  dashboard = {
    desc = "todo dashboard",
    fn = function()
      M.dashboard()
    end,
  },
  toggle = {
    desc = "toggle checkbox",
    fn = function()
      M.toggle_todo()
    end,
  },
  follow_link = {
    desc = "follow [[link]]",
    fn = function()
      M.follow_link()
    end,
  },
  backlinks = {
    desc = "backlinks",
    fn = function()
      M.backlinks()
    end,
  },
  open_todo = {
    desc = "project todos",
    fn = function()
      M.open_todo()
    end,
  },
}

local function apply_keymaps()
  if type(M.options.keymaps) ~= "table" then
    return -- keymaps = false: the user binds their own
  end
  for name, action in pairs(keymap_actions) do
    local lhs = M.options.keymaps[name]
    if type(lhs) == "string" then
      vim.keymap.set("n", lhs, action.fn, { desc = "moor: " .. action.desc })
    end
  end
end

--- Configure moor. Optional for the features, but this is what applies the
--- default keymaps — call it (lazy.nvim's `opts = {}` does) or bind your own.
---@param opts? MoorOptions
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
  apply_keymaps()
end

-- ── Thin delegating API (bind these directly in your own keymaps) ────────────

--- Open the capture float.
---@param opts? {mode?: "note"|"todo", context?: boolean}
function M.capture(opts)
  require("moor.capture").open(opts)
end

--- Open the aggregated open-todo dashboard.
function M.dashboard()
  require("moor.dashboard").open()
end

--- Toggle the checkbox on the current line (works in any buffer).
function M.toggle_todo()
  require("moor.todo").toggle_line()
end

--- One-motion todo capture via vim.ui.input. Moored to the current cursor
--- position by default; pass { context = false } for a plain todo.
---@param opts? {context?: boolean}
function M.add_todo(opts)
  require("moor.todo").prompt(opts)
end

--- Follow the [[wikilink]] under the cursor, offering to create a missing note.
function M.follow_link()
  require("moor.links").follow()
end

--- List backlinks to the current note and jump to a selection.
function M.backlinks()
  require("moor.links").show_backlinks()
end

--- Open the project todo view — the dashboard scoped to this project's todo
--- file, with done tasks kept visible and struck through.
function M.open_todo()
  require("moor.dashboard").open({ scope = "project" })
end

return M
