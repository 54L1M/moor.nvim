-- tests/due_spec.lua
-- Pure due-date logic: relative-shortcut expansion and token lookup.
-- All cases pin `now` to Friday 2026-08-21 so results are deterministic.

local due = require("moor.due")

local NOW = os.time({ year = 2026, month = 8, day = 21, hour = 12 }) -- a Friday

describe("due.expand", function()
  local function exp(text)
    return due.expand(text, NOW)
  end

  it("expands today and tomorrow", function()
    assert.are.equal("pay rent due:2026-08-21", exp("pay rent due:today"), "today")
    assert.are.equal("pay rent due:2026-08-22", exp("pay rent due:tomorrow"), "tomorrow")
  end)

  it("expands day and week offsets", function()
    assert.are.equal("x due:2026-08-24", exp("x due:3d"), "3 days out")
    assert.are.equal("x due:2026-09-04", exp("x due:2w"), "2 weeks out, month rollover")
  end)

  it("expands weekday names to the coming occurrence", function()
    assert.are.equal("x due:2026-08-24", exp("x due:mon"), "next monday from a friday")
    assert.are.equal("x due:2026-08-24", exp("x due:monday"), "full names work")
    assert.are.equal("x due:2026-08-21", exp("x due:fri"), "the same weekday means today")
    assert.are.equal("x due:2026-08-23", exp("x due:SUN"), "case-insensitive")
  end)

  it("leaves absolute dates and unknown words untouched", function()
    assert.are.equal("x due:2027-01-01", exp("x due:2027-01-01"), "absolute dates pass through")
    assert.are.equal("x due:whenever", exp("x due:whenever"), "unknown words are never mangled")
    assert.are.equal(
      "meet a friend due:2026-08-21",
      exp("meet a friend due:fri"),
      "prose like 'friend' is untouched; only the token expands"
    )
  end)

  it("expands every token on the line", function()
    assert.are.equal("a due:2026-08-21 b due:2026-08-22", exp("a due:today b due:tomorrow"), "multiple tokens")
  end)
end)

describe("due.find", function()
  it("locates and classifies a token", function()
    local d = due.find("fix it due:2026-08-22 soon", NOW)
    assert.is_not_nil(d, "token must be found")
    assert.are.equal("2026-08-22", d.date, "date extracted")
    assert.are.equal("future", d.status, "tomorrow is future")
    assert.are.equal("due:2026-08-22", ("fix it due:2026-08-22 soon"):sub(d.from, d.to), "byte range covers the token")
  end)

  it("classifies today and overdue", function()
    assert.are.equal("today", due.find("x due:2026-08-21", NOW).status, "same day is today")
    assert.are.equal("overdue", due.find("x due:2026-08-20", NOW).status, "past dates are overdue")
  end)

  it("returns nil without a token", function()
    assert.is_nil(due.find("no dates here", NOW), "no token yields nil")
    assert.is_nil(due.find("due:tomorrow unexpanded", NOW), "relative words are not absolute tokens")
  end)
end)
