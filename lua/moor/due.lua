-- moor/due.lua
-- Due dates as inline "due:YYYY-MM-DD" tokens — the ZenNotes-native syntax,
-- so dates written here parse on the phone too. Pure Lua: expansion of
-- relative shortcuts (due:tomorrow, due:fri, due:3d) into absolute dates at
-- save time, and token lookup for the dashboard's rendering.

local M = {}

-- sun=1 … sat=7, matching os.date("*t").wday. Exact 3-letter or full names
-- only — a prefix match would swallow words like "friend".
local WEEKDAYS = {}
for i, name in ipairs({ "sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday" }) do
  WEEKDAYS[name] = i
  WEEKDAYS[name:sub(1, 3)] = i
end

---@param word string @param now integer @return string|nil date "YYYY-MM-DD"
local function resolve(word, now)
  local w = word:lower()
  local days
  if w == "today" then
    days = 0
  elseif w == "tomorrow" then
    days = 1
  else
    local n, unit = w:match("^(%d+)([dw])$")
    if n then
      days = tonumber(n) * (unit == "w" and 7 or 1)
    elseif WEEKDAYS[w] then
      -- The coming such weekday; the same day counts as today.
      days = (WEEKDAYS[w] - os.date("*t", now).wday) % 7
    end
  end
  if not days then
    return nil
  end
  local t = os.date("*t", now)
  -- day+n with hour=12 lets os.time normalize month/year rollovers, DST-safe.
  return os.date("%Y-%m-%d", os.time({ year = t.year, month = t.month, day = t.day + days, hour = 12 }))
end

--- Rewrite relative "due:" shortcuts into absolute dates. Absolute dates and
--- unrecognized words pass through untouched, so nothing is ever mangled.
---@param text string
---@param now? integer  Injectable epoch seconds for tests; defaults to os.time()
---@return string
function M.expand(text, now)
  now = now or os.time()
  return (
    text:gsub("(due:)(%S+)", function(prefix, word)
      if word:match("^%d%d%d%d%-%d%d%-%d%d$") then
        return prefix .. word
      end
      return prefix .. (resolve(word, now) or word)
    end)
  )
end

---@class MoorDue
---@field date string  "YYYY-MM-DD"
---@field from integer 1-based byte start of the token in the given string
---@field to integer   1-based byte end (inclusive)
---@field status "future"|"today"|"overdue"

--- Locate the first absolute due token in a string and classify it.
---@param text string
---@param now? integer
---@return MoorDue|nil
function M.find(text, now)
  local from, to = text:find("due:%d%d%d%d%-%d%d%-%d%d")
  if not from then
    return nil
  end
  local date = text:sub(from + 4, to)
  local today = os.date("%Y-%m-%d", now or os.time()) --[[@as string]]
  local status = (date < today and "overdue") or (date == today and "today") or "future"
  return { date = date, from = from, to = to, status = status }
end

return M
