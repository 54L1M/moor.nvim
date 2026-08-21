-- tests/todo_spec.lua
-- Per-project todo file operations over a fixture vault.

local todo = require("moor.todo")

describe("todo", function()
  local root, proj

  before_each(function()
    root = vim.fn.tempname()
    proj = vim.fn.tempname()
    vim.fn.mkdir(root, "p")
    vim.fn.mkdir(proj .. "/.git", "p")
    require("moor").setup({ notes_dir = root })
    vim.cmd.cd(proj)
  end)

  after_each(function()
    vim.fn.delete(root, "rf")
    vim.fn.delete(proj, "rf")
  end)

  it("keys the todo file by project name", function()
    local expected = vim.fs.joinpath(root, "todo", vim.fs.basename(proj) .. ".md")
    assert.are.equal(expected, todo.file(), "todo file lives at todo/<project>.md")
  end)

  it("adds a task line, creating the file with a header", function()
    assert.is_true(todo.add("fix the mooring line"), "add must succeed")
    local lines = require("moor.vault").read_lines(todo.file())
    assert.are.equal("- [ ] fix the mooring line", lines[#lines], "task appended")
    assert.is_truthy(lines[1]:find("^# "), "new todo file gets a title header")
  end)

  it("refuses blank todos", function()
    assert.is_false(todo.add("   "), "blank text must be rejected")
    assert.is_nil(require("moor.vault").read_lines(todo.file()), "no file created for a blank todo")
  end)

  it("moors a context onto the task", function()
    todo.add("check this", { path = "src/x.go", lnum = 12 })
    local lines = require("moor.vault").read_lines(todo.file())
    assert.are.equal("- [ ] check this · `src/x.go:12`", lines[#lines], "context code span appended")
  end)

  describe("prompt", function()
    local function with_input(text, fn)
      local orig = vim.ui.input
      vim.ui.input = function(_, on_confirm) ---@diagnostic disable-line: duplicate-set-field
        on_confirm(text)
      end
      fn()
      vim.ui.input = orig
    end

    it("moors the todo by default", function()
      vim.fn.writefile({ "l1", "l2" }, proj .. "/main.go")
      vim.cmd.edit(proj .. "/main.go")
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      with_input("from the prompt", function()
        todo.prompt()
      end)
      local lines = require("moor.vault").read_lines(todo.file())
      assert.are.equal("- [ ] from the prompt · `main.go:2`", lines[#lines], "prompt todos are moored by default")
    end)

    it("skips the mooring with context = false", function()
      vim.fn.writefile({ "l1" }, proj .. "/main.go")
      vim.cmd.edit(proj .. "/main.go")
      with_input("plain one", function()
        todo.prompt({ context = false })
      end)
      local lines = require("moor.vault").read_lines(todo.file())
      assert.are.equal("- [ ] plain one", lines[#lines], "context = false yields a plain todo")
    end)
  end)

  describe("toggle_line", function()
    it("toggles the checkbox under the cursor", function()
      vim.cmd("enew")
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "- [ ] flip me" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      todo.toggle_line()
      assert.are.equal("- [x] flip me", vim.api.nvim_get_current_line(), "line toggled in place")
      vim.cmd("bwipeout!")
    end)
  end)

  describe("collect", function()
    it("scopes to given paths and can include done tasks", function()
      vim.fn.writefile({ "# A", "- [ ] open one", "- [x] done one" }, root .. "/A.md")
      vim.fn.writefile({ "# B", "- [ ] elsewhere" }, root .. "/B.md")
      local items = todo.collect({ paths = { root .. "/A.md" }, include_done = true })
      assert.are.equal(2, #items, "only A.md scanned, done included")
      assert.are.equal("x", items[2].task.state, "done task carried through")
    end)
  end)

  describe("collect_open", function()
    it("collects open tasks across the vault, skipping done ones", function()
      vim.fn.writefile({ "# A", "- [ ] one", "- [x] done", "- [ ] two" }, root .. "/A.md")
      vim.fn.mkdir(root .. "/inbox", "p")
      vim.fn.writefile({ "# B", "- [ ] three" }, root .. "/inbox/B.md")
      local items = todo.collect_open()
      assert.are.equal(3, #items, "three open tasks expected")
      assert.are.equal("one", items[1].task.text, "first open task text")
      assert.are.equal(2, items[1].lnum, "line number recorded")
    end)
  end)

  describe("toggle_at", function()
    it("toggles a task on disk", function()
      vim.fn.writefile({ "# A", "- [ ] flip" }, root .. "/A.md")
      local item = todo.collect_open()[1]
      assert.is_true(todo.toggle_at(item), "toggle must succeed on an unchanged file")
      local lines = require("moor.vault").read_lines(root .. "/A.md")
      assert.are.equal("- [x] flip", lines[2], "line rewritten on disk")
    end)

    it("rejects a stale item and leaves the file untouched", function()
      vim.fn.writefile({ "# A", "- [ ] flip" }, root .. "/A.md")
      local item = todo.collect_open()[1]
      -- The phone got there first: the note changed underneath us.
      vim.fn.writefile({ "# A", "inserted line", "- [ ] flip" }, root .. "/A.md")
      assert.is_false(todo.toggle_at(item), "stale line numbers must be rejected")
      local lines = require("moor.vault").read_lines(root .. "/A.md")
      assert.are.equal("inserted line", lines[2], "file must be untouched after a rejected toggle")
    end)
  end)
end)
