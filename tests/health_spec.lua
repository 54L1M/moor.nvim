-- tests/health_spec.lua
-- :checkhealth moor renders a report without erroring.

describe("checkhealth", function()
  it("reports on the configured vault", function()
    local root = vim.fn.tempname()
    vim.fn.mkdir(root, "p")
    require("moor").setup({ notes_dir = root })
    vim.cmd("checkhealth moor")
    local report = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
    assert.is_truthy(report:find("moor"), "report must mention moor")
    assert.is_truthy(report:find("notes_dir exists"), "report must confirm the vault: " .. report:sub(1, 400))
    assert.is_truthy(report:find("notes scanned"), "report must include the scan stat")
    assert.is_falsy(report:find("ERROR"), "a healthy setup must produce no errors: " .. report:sub(1, 400))
    vim.cmd("bwipeout!")
    vim.fn.delete(root, "rf")
  end)
end)
