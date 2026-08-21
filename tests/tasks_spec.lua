-- tests/tasks_spec.lua
-- Pure task-line contract: parse / toggle / format round-trips.

local tasks = require("moor.tasks")

describe("tasks.parse", function()
  it("parses an open task", function()
    local t = tasks.parse("- [ ] fix the loader")
    assert.is_not_nil(t, "open task line must parse")
    assert.are.equal(" ", t.state, "state must be a single space")
    assert.are.equal("fix the loader", t.text, "text must exclude the checkbox")
    assert.are.equal("", t.indent, "no indent expected")
    assert.is_true(tasks.is_open(t), "state ' ' means open")
  end)

  it("parses done, cancelled and indented tasks", function()
    for _, case in ipairs({
      { line = "- [x] shipped", state = "x", indent = "" },
      { line = "- [-] nope", state = "-", indent = "" },
      { line = "    - [ ] nested", state = " ", indent = "    " },
      { line = "\t- [x] tabbed", state = "x", indent = "\t" },
    }) do
      local t = tasks.parse(case.line)
      assert.is_not_nil(t, ("%q must parse"):format(case.line))
      assert.are.equal(case.state, t.state, ("%q state"):format(case.line))
      assert.are.equal(case.indent, t.indent, ("%q indent"):format(case.line))
      assert.is_false(t.state == " " and case.state ~= " ", "state mismatch")
    end
  end)

  it("rejects non-task lines", function()
    for _, line in ipairs({
      "- [] missing state",
      "- [ ]no space after brackets",
      "* [ ] star bullets are not ours",
      "just prose",
      "-[ ] no space after dash",
      "# heading",
      "",
    }) do
      assert.is_nil(tasks.parse(line), ("%q must not parse as a task"):format(line))
    end
  end)

  it("extracts a trailing code context", function()
    local t = tasks.parse("- [ ] handle nil palette · `lua/oshen/palette.lua:41`")
    assert.is_not_nil(t.context, "trailing code span must become context")
    assert.are.equal("lua/oshen/palette.lua", t.context.path, "context path")
    assert.are.equal(41, t.context.lnum, "context line number")
  end)
end)

describe("tasks.toggle", function()
  local states = { " ", "x" }

  it("cycles open -> done -> open", function()
    local done = tasks.toggle("- [ ] write spec", states)
    assert.are.equal("- [x] write spec", done, "open must toggle to done")
    assert.are.equal("- [ ] write spec", tasks.toggle(done, states), "done must toggle back to open")
  end)

  it("resets an unknown state to the first configured one", function()
    assert.are.equal("- [ ] weird", tasks.toggle("- [?] weird", states), "unknown state resets to first")
  end)

  it("supports a three-state cycle", function()
    local three = { " ", "x", "-" }
    assert.are.equal("- [-] t", tasks.toggle("- [x] t", three), "x cycles to -")
    assert.are.equal("- [ ] t", tasks.toggle("- [-] t", three), "- cycles back to open")
  end)

  it("preserves indentation", function()
    assert.are.equal("  - [x] nested", tasks.toggle("  - [ ] nested", states), "indent must survive toggle")
  end)

  it("returns nil for non-task lines", function()
    assert.is_nil(tasks.toggle("prose line", states), "prose must not toggle")
  end)
end)

describe("tasks.format", function()
  it("builds a plain open task", function()
    assert.are.equal("- [ ] call the harbor", tasks.format("call the harbor"), "plain format")
  end)

  it("trims the text", function()
    assert.are.equal("- [ ] tidy", tasks.format("  tidy  "), "text must be trimmed")
  end)

  it("appends a moored code context", function()
    local line = tasks.format("fix race", { path = "lua/moor/init.lua", lnum = 33 })
    assert.are.equal("- [ ] fix race · `lua/moor/init.lua:33`", line, "context code span format")
  end)

  it("round-trips through parse", function()
    local line = tasks.format("fix race", { path = "src/a.go", lnum = 7 })
    local t = tasks.parse(line)
    assert.is_not_nil(t, "formatted line must parse")
    assert.are.equal("src/a.go", t.context.path, "round-trip path")
    assert.are.equal(7, t.context.lnum, "round-trip lnum")
  end)
end)
