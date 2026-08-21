-- tests/dashboard_spec.lua
-- The open-todo dashboard: rendering, toggling, jumping.

local dashboard = require("moor.dashboard")

describe("dashboard", function()
  local root

  local function dash_lines()
    return vim.api.nvim_buf_get_lines(0, 0, -1, false)
  end

  before_each(function()
    root = vim.fn.tempname()
    vim.fn.mkdir(root, "p")
    require("moor").setup({ notes_dir = root })
    vim.fn.writefile({ "# A", "- [ ] one", "- [x] done", "- [ ] two · `src/x.go:3`" }, root .. "/A.md")
    vim.fn.mkdir(root .. "/inbox", "p")
    vim.fn.writefile({ "# B", "- [ ] three" }, root .. "/inbox/B.md")
  end)

  after_each(function()
    vim.cmd("silent! %bwipeout!")
    vim.fn.delete(root, "rf")
  end)

  it("renders open todos grouped by note", function()
    dashboard.open()
    local lines = dash_lines()
    assert.are.equal("moor-dashboard", vim.bo.filetype, "dashboard buffer filetype")
    assert.is_false(vim.bo.modifiable, "dashboard is read-only")
    assert.are.equal(" A.md (2)", lines[1], "group header with count")
    assert.are.equal("   ○ one", lines[2], "first open task")
    assert.are.equal("   ○ two · `src/x.go:3`", lines[3], "moored task rendered verbatim")
    assert.are.equal(" inbox/B.md (1)", lines[5], "second group after a blank line")
  end)

  it("reopening focuses the same buffer", function()
    dashboard.open()
    local buf = vim.api.nvim_get_current_buf()
    dashboard.open()
    assert.are.equal(buf, vim.api.nvim_get_current_buf(), "dashboard is a singleton")
  end)

  it("toggling completes the task on disk and drops it from the view", function()
    dashboard.open()
    vim.api.nvim_win_set_cursor(0, { 2, 0 }) -- "[ ] one"
    vim.api.nvim_feedkeys("t", "x", false)
    assert.are.equal("- [x] one", vim.fn.readfile(root .. "/A.md")[2], "toggle lands on disk")
    assert.are.equal(" A.md (1)", dash_lines()[1], "completed item disappears from the render")
  end)

  it("jumps to the source note line", function()
    dashboard.open()
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "x", false)
    assert.is_truthy(vim.api.nvim_buf_get_name(0):find("A%.md$"), "jump edits the source note")
    assert.are.equal(2, vim.api.nvim_win_get_cursor(0)[1], "cursor lands on the task line")
  end)

  it("pins a key-hint footer to the float border", function()
    dashboard.open()
    local config = vim.api.nvim_win_get_config(0)
    assert.is_not_nil(config.footer, "the float border must carry a footer")
    local text = config.footer[1][1]
    assert.is_truthy(text:find("t toggle"), "footer must list the toggle key")
    assert.is_truthy(text:find("q close"), "footer must list the close key")
    assert.is_nil(dash_lines()[#dash_lines()]:find("t toggle"), "the hint must not live in the buffer")
  end)

  it("renders wikilinks without brackets, highlighted as links", function()
    vim.fn.writefile({ "# L", "- [ ] read [[Binary trees]] — BFS/DFS", "- [ ] see [[Go|golang]]" }, root .. "/L.md")
    dashboard.open()
    local lines = dash_lines()
    local by_text = {}
    for _, l in ipairs(lines) do
      by_text[l] = true
    end
    assert.is_true(by_text["   ○ read Binary trees — BFS/DFS"], "brackets stripped: " .. vim.inspect(lines))
    assert.is_true(by_text["   ○ see golang"], "aliased link shows the alias")
    local link_marked = false
    for _, m in
      ipairs(
        vim.api.nvim_buf_get_extmarks(0, vim.api.nvim_get_namespaces()["moor.dashboard"], 0, -1, { details = true })
      )
    do
      link_marked = link_marked or m[4].hl_group == "MoorLink"
    end
    assert.is_true(link_marked, "link labels must carry the MoorLink highlight")
  end)

  it("highlights due tokens, with an accent for overdue", function()
    vim.fn.writefile({ "# D", "- [ ] future thing due:2999-01-01", "- [ ] late thing due:2020-01-01" }, root .. "/D.md")
    dashboard.open()
    local found = {}
    for _, m in
      ipairs(
        vim.api.nvim_buf_get_extmarks(0, vim.api.nvim_get_namespaces()["moor.dashboard"], 0, -1, { details = true })
      )
    do
      found[m[4].hl_group] = true
    end
    assert.is_true(found["MoorDue"] == true, "future due tokens carry MoorDue")
    assert.is_true(found["MoorOverdue"] == true, "overdue tokens carry MoorOverdue")
  end)

  it("s toggles a flat soonest-first sort and back", function()
    vim.fn.writefile({ "# S", "- [ ] later due:2999-06-01", "- [ ] sooner due:2999-01-01" }, root .. "/S.md")
    dashboard.open()
    vim.api.nvim_feedkeys("s", "x", false)
    local lines = dash_lines()
    assert.are.equal("   ○ sooner due:2999-01-01 · S.md", lines[1], "soonest dated item first, note as dim suffix")
    assert.are.equal("   ○ later due:2999-06-01 · S.md", lines[2], "then the next date")
    assert.is_truthy(lines[3]:find("· A%.md$"), "undated items follow in file order")
    assert.is_truthy(vim.api.nvim_win_get_config(0).title[1][1]:find("by due"), "window title shows the sort mode")
    vim.api.nvim_feedkeys("s", "x", false)
    assert.are.equal(" A.md (2)", dash_lines()[1], "pressing s again restores the grouped view")
  end)

  it("falls back to raw brackets with icons = false", function()
    require("moor").setup({ notes_dir = root, dashboard = { icons = false } })
    dashboard.open()
    assert.are.equal("   [ ] one", dash_lines()[2], "icons = false shows plain markdown brackets")
  end)

  it("toggle_todo delegates to the dashboard toggle", function()
    dashboard.open()
    vim.api.nvim_win_set_cursor(0, { 2, 0 }) -- "[ ] one"
    require("moor").toggle_todo()
    assert.are.equal("- [x] one", vim.fn.readfile(root .. "/A.md")[2], "the everywhere-toggle works in the dashboard")
  end)

  describe("project scope", function()
    local proj

    before_each(function()
      proj = vim.fn.tempname()
      vim.fn.mkdir(proj .. "/.git", "p")
      vim.cmd.cd(proj)
      vim.fn.mkdir(root .. "/todo", "p")
      local name = vim.fs.basename(proj)
      vim.fn.writefile({ "# " .. name, "", "- [ ] still open", "- [x] shipped" }, root .. "/todo/" .. name .. ".md")
    end)

    after_each(function()
      vim.fn.delete(proj, "rf")
    end)

    it("shows only the project todo file, done tasks struck through", function()
      dashboard.open({ scope = "project" })
      local lines = dash_lines()
      assert.is_truthy(lines[1]:find("%(1%)$"), "header counts open tasks only")
      assert.are.equal("   ○ still open", lines[2], "open task rendered")
      assert.are.equal("   ✓ shipped", lines[3], "done task stays visible")
      assert.are.equal(3, #lines, "other vault notes are out of scope, and no footer line in the buffer")
      local done_mark_found = false
      for _, m in
        ipairs(
          vim.api.nvim_buf_get_extmarks(0, vim.api.nvim_get_namespaces()["moor.dashboard"], 0, -1, { details = true })
        )
      do
        done_mark_found = done_mark_found or m[4].hl_group == "MoorDone"
      end
      assert.is_true(done_mark_found, "done task text must carry the MoorDone strikethrough mark")
      local hl = vim.api.nvim_get_hl(0, { name = "MoorDone", link = false })
      assert.is_true(hl.strikethrough == true, "MoorDone must define strikethrough")
    end)

    it("keeps a toggled item visible instead of dropping it", function()
      dashboard.open({ scope = "project" })
      vim.api.nvim_win_set_cursor(0, { 2, 0 }) -- "[ ] still open"
      vim.api.nvim_feedkeys("t", "x", false)
      assert.are.equal("   ✓ still open", dash_lines()[2], "toggled item stays, now done")
      vim.api.nvim_feedkeys("t", "x", false)
      assert.are.equal("   ○ still open", dash_lines()[2], "toggle again reopens it")
    end)

    it("re-scopes an already-open dashboard", function()
      dashboard.open()
      dashboard.open({ scope = "project" })
      assert.is_truthy(dash_lines()[2]:find("still open"), "the same window now shows the project view")
    end)
  end)

  it("jumps to the moored code context", function()
    vim.fn.mkdir(root .. "/src", "p")
    vim.fn.writefile({ "l1", "l2", "l3" }, root .. "/src/x.go")
    vim.cmd.cd(root) -- make `src/x.go:3` resolvable from cwd
    dashboard.open()
    vim.api.nvim_win_set_cursor(0, { 3, 0 }) -- "[ ] two · `src/x.go:3`"
    vim.api.nvim_feedkeys("gd", "x", false)
    assert.is_truthy(vim.api.nvim_buf_get_name(0):find("x%.go$"), "gd edits the moored file")
    assert.are.equal(3, vim.api.nvim_win_get_cursor(0)[1], "cursor lands on the moored line")
  end)
end)
