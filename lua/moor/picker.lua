-- moor/picker.lua
-- The single seam every list UI goes through. v1 wraps vim.ui.select verbatim,
-- which already respects the user's picker (telescope ui-select, snacks,
-- fzf-lua, dressing, mini.pick). Native adapters can land here later without
-- touching any feature module.

local M = {}

--- Pick one item.
---@generic T
---@param items T[]
---@param opts {prompt: string, format: fun(item: T): string}
---@param on_choice fun(item: T|nil)
function M.select(items, opts, on_choice)
  vim.ui.select(items, { prompt = opts.prompt, format_item = opts.format }, on_choice)
end

return M
