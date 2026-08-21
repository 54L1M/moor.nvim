-- tests/links_spec.lua
-- Wikilink detection, resolution and the backlink scan.

local links = require("moor.links")

describe("links", function()
  local root

  local function note(rel, lines)
    local path = vim.fs.joinpath(root, rel)
    vim.fn.mkdir(vim.fs.dirname(path), "p")
    vim.fn.writefile(lines, path)
    return path
  end

  before_each(function()
    root = vim.fn.tempname()
    vim.fn.mkdir(root, "p")
    require("moor").setup({ notes_dir = root })
  end)

  after_each(function()
    vim.fn.delete(root, "rf")
    vim.cmd("silent! %bwipeout!")
  end)

  describe("link_at_cursor", function()
    local function at(line, col)
      vim.cmd("enew")
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { line })
      vim.api.nvim_win_set_cursor(0, { 1, col })
      local title = links.link_at_cursor()
      vim.cmd("bwipeout!")
      return title
    end

    it("finds the link spanning the cursor", function()
      assert.are.equal("Go", at("see [[Go]] for more", 5), "cursor on the brackets counts")
      assert.are.equal("Go", at("see [[Go]] for more", 7), "cursor inside the title counts")
    end)

    it("picks the right link among several on one line", function()
      local line = "[[Queue]] · [[Stack]] · array list"
      assert.are.equal("Queue", at(line, 2), "first link")
      assert.are.equal("Stack", at(line, 14), "second link")
    end)

    it("returns nil off-link", function()
      assert.is_nil(at("see [[Go]] for more", 12), "cursor after the link yields nil")
      assert.is_nil(at("no links here", 3), "plain prose yields nil")
    end)

    it("strips alias and heading decorations", function()
      assert.are.equal("Go", at("[[Go|the language]]", 3), "alias stripped")
      assert.are.equal("Go", at("[[Go#Roadmap]]", 3), "heading stripped")
    end)
  end)

  describe("backlinks_to", function()
    it("finds plain, aliased and heading links, case-insensitively", function()
      note("Go.md", { "# Go" })
      note("A.md", { "# A", "learning [[Go]] now" })
      note("inbox/B.md", { "# B", "see [[go|golang]]", "and [[Go#Roadmap]]" })
      note("C.md", { "# C", "no links" })
      local bl = links.backlinks_to("Go")
      assert.are.equal(3, #bl, "three linking lines expected, got " .. vim.inspect(bl))
    end)

    it("ignores ignored dirs and self-links", function()
      note("Go.md", { "# Go", "self [[Go]] mention" })
      note("trash/T.md", { "# T", "[[Go]]" })
      assert.are.equal(0, #links.backlinks_to("Go"), "self-links and trash must not count")
    end)
  end)

  describe("follow", function()
    it("opens an existing note by title", function()
      local path = note("inbox/Target.md", { "# Target" })
      vim.cmd("enew")
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "go to [[Target]]" })
      vim.api.nvim_win_set_cursor(0, { 1, 9 })
      links.follow()
      -- resolve() both sides: on macOS /var is a symlink to /private/var
      assert.are.equal(
        vim.fn.resolve(path),
        vim.fn.resolve(vim.api.nvim_buf_get_name(0)),
        "follow must edit the resolved note"
      )
    end)

    it("offers to create a missing note", function()
      local asked
      local orig = vim.ui.select
      vim.ui.select = function(_, opts, on_choice) ---@diagnostic disable-line: duplicate-set-field
        asked = opts.prompt
        on_choice("Yes")
      end
      vim.cmd("enew")
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "[[Brand New]]" })
      vim.api.nvim_win_set_cursor(0, { 1, 3 })
      links.follow()
      vim.ui.select = orig
      assert.is_truthy(asked and asked:find("Brand New"), "user must be asked before creating")
      assert.is_truthy(vim.api.nvim_buf_get_name(0):find("Brand New%.md$"), "created note is opened")
      assert.are.same({ "# Brand New", "" }, vim.fn.readfile(root .. "/Brand New.md"), "note created on disk")
    end)
  end)
end)
