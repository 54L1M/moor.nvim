-- tests/vault_spec.lua
-- Filesystem contract over a throwaway fixture vault.

local vault = require("moor.vault")

describe("vault", function()
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
  end)

  describe("list_notes", function()
    it("lists markdown files recursively and skips ignored dirs", function()
      note("Go.md", { "# Go" })
      note("inbox/Deep.md", { "# Deep" })
      note("trash/Gone.md", { "# Gone" })
      note("archive/Old.md", { "# Old" })
      note("inbox/readme.txt", { "not markdown" })
      local paths = vault.list_notes()
      assert.are.equal(2, #paths, "only live .md files: got " .. vim.inspect(paths))
      assert.is_truthy(paths[1]:find("Go%.md$"), "root note listed")
      assert.is_truthy(paths[2]:find("Deep%.md$"), "nested note listed")
    end)

    it("returns an empty list for a missing notes_dir", function()
      require("moor").setup({ notes_dir = root .. "/nope" })
      assert.are.same({}, vault.list_notes(), "missing dir must not error")
    end)
  end)

  describe("read_lines", function()
    it("returns nil for a missing file", function()
      assert.is_nil(vault.read_lines(root .. "/ghost.md"), "missing file yields nil, never an error")
    end)

    it("reads a note without a trailing blank artifact", function()
      local path = note("A.md", { "# A", "", "body" })
      assert.are.same({ "# A", "", "body" }, vault.read_lines(path), "lines round-trip")
    end)

    it("prefers a loaded buffer over disk", function()
      local path = note("B.md", { "# B" })
      vim.cmd.edit(path)
      vim.api.nvim_buf_set_lines(0, -1, -1, false, { "unsaved edit" })
      local lines = vault.read_lines(path)
      assert.are.equal("unsaved edit", lines[#lines], "unsaved buffer content must win")
      vim.cmd("bwipeout!")
    end)
  end)

  describe("append_lines", function()
    it("creates parent dirs and a # Title header for a new note", function()
      local path = vim.fs.joinpath(root, "todo", "pf4.md")
      assert.is_true(vault.append_lines(path, { "- [ ] first" }), "append must succeed")
      assert.are.same({ "# pf4", "", "- [ ] first" }, vault.read_lines(path), "new file gets a title header")
    end)

    it("appends to an existing note without touching its header", function()
      local path = note("C.md", { "# C", "", "- [ ] one" })
      vault.append_lines(path, { "- [ ] two" })
      assert.are.same({ "# C", "", "- [ ] one", "- [ ] two" }, vault.read_lines(path), "append preserves content")
    end)
  end)

  describe("titles", function()
    it("resolves a title to a nested path, case-insensitively", function()
      local path = note("inbox/Deep Note.md", { "# Deep Note" })
      assert.are.equal(path, vault.path_for_title("Deep Note"), "exact title resolves")
      assert.are.equal(path, vault.path_for_title("deep note"), "case-insensitive resolve")
      assert.is_nil(vault.path_for_title("Missing"), "unknown title yields nil")
    end)

    it("derives the title from the filename", function()
      assert.are.equal("Deep Note", vault.title_for_path("/x/inbox/Deep Note.md"), "basename sans .md")
    end)
  end)

  describe("create_note", function()
    it("creates a titled note in links.new_note_dir", function()
      require("moor").setup({ notes_dir = root, links = { new_note_dir = "inbox" } })
      local path = vault.create_note("Fresh")
      assert.is_truthy(path:find("inbox/Fresh%.md$"), "created under new_note_dir")
      assert.are.same({ "# Fresh", "" }, vault.read_lines(path), "created with title header")
    end)
  end)
end)
