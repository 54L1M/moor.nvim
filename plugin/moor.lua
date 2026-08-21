-- plugin/moor.lua
-- :Moor entry point. The callback lazy-requires, the completion list is a
-- static table — nothing of moor loads at startup.

if vim.g.loaded_moor then
  return
end
vim.g.loaded_moor = true

vim.api.nvim_create_user_command("Moor", function(cmd)
  require("moor.cmd").run(cmd)
end, {
  nargs = "*",
  desc = "moor.nvim — notes and todos moored to your code",
  complete = function(_, cmdline)
    if cmdline:match("^Moor%s+capture%s") then
      return { "todo", "context" }
    end
    if cmdline:match("^Moor%s+todo%s") then
      return { "plain" }
    end
    if cmdline:match("^Moor%s+%S+%s") then
      return {}
    end
    return { "capture", "todo", "dashboard", "toggle", "follow", "backlinks", "open" }
  end,
})
