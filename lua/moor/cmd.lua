-- moor/cmd.lua
-- :Moor subcommand dispatcher. Kept out of init.lua so the public API file
-- stays a clean list of functions.

local M = {}

local subcommands = {
  capture = function(args)
    require("moor").capture({
      mode = vim.tbl_contains(args, "todo") and "todo" or "note",
      context = vim.tbl_contains(args, "context"),
    })
  end,
  todo = function(args)
    -- Moored by default; ":Moor todo plain" skips the file:line reference.
    require("moor").add_todo({ context = not vim.tbl_contains(args, "plain") })
  end,
  dashboard = function()
    require("moor").dashboard()
  end,
  toggle = function()
    require("moor").toggle_todo()
  end,
  follow = function()
    require("moor").follow_link()
  end,
  backlinks = function()
    require("moor").backlinks()
  end,
  open = function()
    require("moor").open_todo()
  end,
  mooring = function()
    require("moor").mooring()
  end,
}

---@param cmd table  The user-command callback table from nvim_create_user_command
function M.run(cmd)
  local args = cmd.fargs
  local name = table.remove(args, 1) or "capture"
  local handler = subcommands[name]
  if not handler then
    vim.notify("moor: unknown subcommand '" .. name .. "'", vim.log.levels.ERROR)
    return
  end
  handler(args)
end

return M
