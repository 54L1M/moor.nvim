-- tests/project_spec.lua
-- Project identity: git root name with cwd-basename fallback.

local project = require("moor.project")

describe("project.identity", function()
  local tmp

  before_each(function()
    tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp .. "/repo/sub", "p")
  end)

  after_each(function()
    vim.fn.delete(tmp, "rf")
  end)

  it("uses the git root basename inside a repo", function()
    vim.fn.mkdir(tmp .. "/repo/.git", "p")
    local name, root = project.identity(tmp .. "/repo/sub")
    assert.are.equal("repo", name, "name must be the git root basename")
    assert.are.equal(vim.fs.normalize(tmp .. "/repo"), vim.fs.normalize(root), "root must be the git root")
  end)

  it("falls back to the cwd basename outside a repo", function()
    local name, root = project.identity(tmp .. "/repo/sub")
    assert.are.equal("sub", name, "fallback is the cwd basename")
    assert.are.equal(vim.fs.normalize(tmp .. "/repo/sub"), vim.fs.normalize(root), "fallback root is the cwd")
  end)
end)
