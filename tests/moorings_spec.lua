-- tests/moorings_spec.lua
-- Code-side moorings: signs on moored lines and the jump back to the todo.

local moorings = require("moor.moorings")

describe("moorings", function()
  local root, proj

  local function sign_lines(buf)
    local out = {}
    local ns = vim.api.nvim_get_namespaces()["moor.moorings"]
    for _, m in ipairs(vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })) do
      if m[4].sign_text then
        out[#out + 1] = m[2] + 1 -- 1-based line
      end
    end
    table.sort(out)
    return out
  end

  before_each(function()
    root = vim.fn.tempname()
    proj = vim.fn.tempname()
    vim.fn.mkdir(root, "p")
    vim.fn.mkdir(proj .. "/.git", "p")
    vim.fn.writefile({ "line1", "line2", "line3" }, proj .. "/main.go")
    require("moor").setup({ notes_dir = root })
    vim.cmd.cd(proj)
  end)

  after_each(function()
    vim.cmd("silent! %bwipeout!")
    vim.fn.delete(root, "rf")
    vim.fn.delete(proj, "rf")
  end)

  it("places a sign on lines with an open moored todo", function()
    require("moor.todo").add("fix this", { path = "main.go", lnum = 2 })
    require("moor.todo").add("done already · ignored", nil)
    vim.cmd.edit(proj .. "/main.go")
    assert.are.same({ 2 }, sign_lines(0), "exactly the moored line carries a sign")
  end)

  it("drops the sign once the todo is completed", function()
    require("moor.todo").add("fix this", { path = "main.go", lnum = 2 })
    vim.cmd.edit(proj .. "/main.go")
    local buf = vim.api.nvim_get_current_buf()
    local item = require("moor.todo").collect_open()[1]
    assert.is_true(require("moor.todo").toggle_at(item), "toggle must succeed")
    assert.are.same({}, sign_lines(buf), "completed todos lose their anchor sign")
  end)

  it("skips references beyond the end of the file", function()
    require("moor.todo").add("dangling", { path = "main.go", lnum = 99 })
    vim.cmd.edit(proj .. "/main.go")
    assert.are.same({}, sign_lines(0), "out-of-range moorings must not error or mark")
  end)

  it("respects moorings = false", function()
    require("moor").setup({ notes_dir = root, moorings = false })
    require("moor.todo").add("fix this", { path = "main.go", lnum = 1 })
    vim.cmd.edit(proj .. "/main.go")
    assert.are.same({}, sign_lines(0), "disabled moorings place no signs")
  end)

  it("jumps from a moored line to its todo", function()
    require("moor.todo").add("fix this", { path = "main.go", lnum = 2 })
    vim.cmd.edit(proj .. "/main.go")
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    moorings.jump()
    -- resolve() both sides: on macOS /var is a symlink to /private/var
    assert.are.equal(
      vim.fn.resolve(require("moor.todo").file()),
      vim.fn.resolve(vim.api.nvim_buf_get_name(0)),
      "jump lands in the project todo file"
    )
    local line = vim.api.nvim_get_current_line()
    assert.is_truthy(line:find("fix this"), "cursor is on the moored todo's line")
  end)
end)
