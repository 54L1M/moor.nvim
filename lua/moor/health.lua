-- moor/health.lua
-- :checkhealth moor — environment and vault sanity.

local M = {}

function M.check()
  local health = vim.health
  health.start("moor.nvim")

  if vim.fn.has("nvim-0.11") == 1 then
    health.ok("Neovim >= 0.11")
  else
    health.error("Neovim 0.11+ required (vim.fs.relpath, vim.hl.range)")
  end

  local vault = require("moor.vault")
  local root = vault.root()
  if vim.fn.isdirectory(root) == 1 then
    health.ok("notes_dir exists: " .. root)
    if vim.uv.fs_access(root, "W") then
      health.ok("notes_dir is writable")
    else
      health.error("notes_dir is not writable")
    end
    local started = vim.uv.hrtime()
    local count = #vault.list_notes()
    local ms = (vim.uv.hrtime() - started) / 1e6
    health.ok(("%d notes scanned in %.1fms"):format(count, ms))
  else
    health.warn(
      "notes_dir does not exist: " .. root,
      "set notes_dir in setup() — moor creates files, not the vault directory itself"
    )
  end

  local name = require("moor.project").identity()
  local todo_file = require("moor.todo").file()
  local exists = vim.uv.fs_stat(todo_file) and "exists" or "will be created on first todo"
  health.info(("project '%s' → %s (%s)"):format(name, vault.relative(todo_file), exists))
end

return M
