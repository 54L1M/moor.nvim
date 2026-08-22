-- tests/completion_spec.lua
-- [[link]] completion: the completefunc contract and vault-only attachment.

local completion = require("moor.completion")

describe("completion", function()
  local root

  before_each(function()
    root = vim.fn.tempname()
    vim.fn.mkdir(root .. "/inbox", "p")
    vim.fn.writefile({ "# Go" }, root .. "/Go.md")
    vim.fn.writefile({ "# Goroutines" }, root .. "/inbox/Goroutines.md")
    vim.fn.writefile({ "# Python" }, root .. "/Python.md")
    require("moor").setup({ notes_dir = root })
  end)

  after_each(function()
    vim.cmd("silent! %bwipeout!")
    vim.fn.delete(root, "rf")
  end)

  describe("completefunc", function()
    local function findstart_at(line, col)
      vim.cmd("enew")
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { line })
      vim.api.nvim_win_set_cursor(0, { 1, col })
      local start = completion.completefunc(1, "")
      vim.cmd("bwipeout!")
      return start
    end

    it("finds the start of an open link", function()
      assert.are.equal(8, findstart_at("learn [[Go", 10), "start is the 0-based byte right after [[")
    end)

    it("cancels outside a link", function()
      assert.are.equal(-3, findstart_at("no link here", 6), "prose must not trigger completion")
      assert.are.equal(-3, findstart_at("closed [[Go]] already", 18), "a closed link must not trigger")
    end)

    it("matches titles case-insensitively, substring included", function()
      vim.cmd("enew")
      local items = completion.completefunc(0, "gor")
      assert.are.equal(1, #items, "one title contains 'gor'")
      assert.are.equal("Goroutines]]", items[1].word, "completed word closes the link")
      assert.are.equal("Goroutines", items[1].abbr, "menu shows the bare title")
      assert.are.equal(3, #completion.completefunc(0, ""), "empty base lists every note")
      vim.cmd("bwipeout!")
    end)

    it("adds only the closing brackets an autopair has not already inserted", function()
      local function completed_word(line, col)
        vim.cmd("enew")
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { line })
        vim.api.nvim_win_set_cursor(0, { 1, col })
        local word = completion.completefunc(0, "gor")[1].word
        vim.cmd("bwipeout!")
        return word
      end
      assert.are.equal("Goroutines", completed_word("[[gor]]", 5), "existing ]] is not duplicated")
      assert.are.equal("Goroutines]", completed_word("[[gor]", 5), "a single ] gets exactly one more")
      assert.are.equal("Goroutines]]", completed_word("[[gor", 5), "nothing following gets the full close")
    end)
  end)

  describe("attachment", function()
    it("attaches to markdown files inside the vault only", function()
      vim.cmd.edit(root .. "/Go.md")
      assert.is_truthy(vim.bo.completefunc:find("moor"), "vault note gets the completefunc")
      local outside = vim.fn.tempname() .. ".md"
      vim.fn.writefile({ "# Elsewhere" }, outside)
      vim.cmd.edit(outside)
      assert.are.equal("", vim.bo.completefunc, "markdown outside the vault is left alone")
      vim.fn.delete(outside)
    end)

    it("attaches to the capture float", function()
      local buf = require("moor.capture").open({ mode = "note" })
      vim.cmd.stopinsert()
      assert.is_truthy(vim.bo[buf].completefunc:find("moor"), "capture buffers complete links too")
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("respects links.completion = false", function()
      require("moor").setup({ notes_dir = root, links = { completion = false } })
      vim.cmd.edit(root .. "/Python.md")
      assert.are.equal("", vim.bo.completefunc, "disabled completion attaches nothing")
    end)
  end)
end)
