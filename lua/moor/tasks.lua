-- moor/tasks.lua
-- Pure task-line logic: parse, toggle, and format markdown checkbox lines.
-- No vim API in here — the file-format contract lives in this module alone.
-- Format: "- [ ] text" / "- [x] text", ZenNotes/Obsidian compatible.

local M = {}

---@class MoorTask
---@field indent string  Leading whitespace, preserved on rewrite
---@field state string   Single char inside the brackets (" ", "x", "-", ...)
---@field text string    Everything after the checkbox
---@field context {path: string, lnum: number}|nil  Trailing code ref, if any

-- ── Parse ────────────────────────────────────────────────────────────────────

--- Parse a markdown task line.
---@param line string
---@return MoorTask|nil
function M.parse(line)
  local indent, state, text = line:match("^(%s*)%- %[(.)%] (.*)$")
  if not indent then
    return nil
  end
  return {
    indent = indent,
    state = state,
    text = text,
    context = require("moor.context").extract(text),
  }
end

---@param task MoorTask
---@return boolean
function M.is_open(task)
  return task.state == " "
end

-- ── Rewrite ──────────────────────────────────────────────────────────────────

--- Cycle a task line's checkbox through `states` (e.g. { " ", "x" }).
--- An unknown current state resets to the first entry.
---@param line string
---@param states string[]
---@return string|nil new_line  nil when the line is not a task
function M.toggle(line, states)
  local task = M.parse(line)
  if not task then
    return nil
  end
  local next_state = states[1]
  for i, s in ipairs(states) do
    if s == task.state then
      next_state = states[i % #states + 1]
      break
    end
  end
  return ("%s- [%s] %s"):format(task.indent, next_state, task.text)
end

--- Build a new open task line, optionally moored to a code location.
---@param text string
---@param context? {path: string, lnum: number}
---@return string
function M.format(text, context)
  local line = ("- [ ] %s"):format(vim.trim(text))
  if context then
    line = ("%s · `%s:%d`"):format(line, context.path, context.lnum)
  end
  return line
end

return M
