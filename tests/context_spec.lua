-- tests/context_spec.lua
-- Code-context reference extraction: the trailing-code-span contract.

local context = require("moor.context")

describe("context.extract", function()
  it("extracts a trailing `path:lnum` span", function()
    local ref = context.extract("do the thing · `lua/moor/vault.lua:120`")
    assert.is_not_nil(ref, "trailing span must extract")
    assert.are.equal("lua/moor/vault.lua", ref.path, "path")
    assert.are.equal(120, ref.lnum, "lnum")
  end)

  it("tolerates trailing whitespace", function()
    assert.is_not_nil(context.extract("t · `a.lua:1`  "), "trailing spaces must not break extraction")
  end)

  it("ignores a mid-line code span", function()
    assert.is_nil(context.extract("see `a.lua:1` for details"), "span must be terminal to count")
  end)

  it("ignores code spans without a line number", function()
    assert.is_nil(context.extract("run `make test`"), "plain code spans are not references")
  end)

  it("ignores backticks elsewhere in the text", function()
    local ref = context.extract("use `errors.Is` here · `pkg/err.go:9`")
    assert.is_not_nil(ref, "earlier spans must not confuse the terminal one")
    assert.are.equal("pkg/err.go", ref.path, "the last span wins")
  end)

  it("returns nil for empty path", function()
    assert.is_nil(context.extract("weird `:12`"), "empty path is not a reference")
  end)
end)

describe("context.current", function()
  it("returns nil for an unnamed buffer", function()
    vim.cmd("enew")
    assert.is_nil(context.current(), "unnamed buffers have no reference")
  end)

  it("captures path and line of a named buffer", function()
    local tmp = vim.fn.tempname() .. ".lua"
    vim.fn.writefile({ "one", "two", "three" }, tmp)
    vim.cmd.edit(tmp)
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    local ref = context.current()
    assert.is_not_nil(ref, "named buffer must yield a reference")
    assert.are.equal(2, ref.lnum, "cursor line captured")
    assert.is_truthy(ref.path:find("%.lua$"), "path captured")
    vim.cmd("bwipeout!")
    vim.fn.delete(tmp)
  end)
end)
