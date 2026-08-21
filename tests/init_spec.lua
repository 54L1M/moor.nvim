-- tests/init_spec.lua
-- setup(): option merging and the default global keymaps.
-- NOTE: keymaps persist in the instance once set, so the "disabled" cases
-- run before any setup() call that would define them.

describe("moor.setup keymaps", function()
  local function lhs_mapped(lhs)
    return vim.fn.maparg(lhs, "n") ~= ""
  end

  it("defines none with keymaps = false", function()
    require("moor").setup({ keymaps = false })
    assert.is_false(lhs_mapped("<leader>nn"), "keymaps = false must define nothing")
    assert.is_false(lhs_mapped("<leader>nd"), "keymaps = false must define nothing")
  end)

  it("skips individually disabled entries", function()
    require("moor").setup({ keymaps = { dashboard = false } })
    assert.is_true(lhs_mapped("<leader>nn"), "other defaults still apply")
    assert.is_false(lhs_mapped("<leader>nd"), "dashboard = false must skip that one map")
  end)

  it("supports rebinding a single entry", function()
    require("moor").setup({ keymaps = { toggle = "<leader>tt" } })
    assert.is_true(lhs_mapped("<leader>tt"), "custom lhs applied")
  end)

  it("applies every default and carries a desc", function()
    require("moor").setup({})
    for _, lhs in ipairs({
      "<leader>nn",
      "<leader>nt",
      "<leader>nT",
      "<leader>na",
      "<leader>nA",
      "<leader>nd",
      "<leader>nx",
      "<leader>nf",
      "<leader>nb",
      "<leader>no",
    }) do
      assert.is_true(lhs_mapped(lhs), lhs .. " must be mapped by default")
    end
    local info = vim.fn.maparg("<leader>nd", "n", false, true)
    assert.is_truthy(info.desc and info.desc:find("^moor: "), "maps carry a moor: desc for which-key")
  end)
end)
