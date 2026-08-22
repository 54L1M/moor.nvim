-- scripts/demo.lua
-- Stage a fake vault + project for taking README screenshots, so no real
-- notes end up in the pictures. Run inside a normal nvim session:
--   :luafile scripts/demo.lua
-- then follow the printed shot list. Everything lives under /tmp and your
-- real notes_dir is only swapped for this session.

local vault = "/tmp/moor-demo-vault"
local proj = "/tmp/harbor"

vim.fn.delete(vault, "rf")
vim.fn.delete(proj, "rf")
vim.fn.mkdir(vault .. "/todo", "p")
vim.fn.mkdir(proj .. "/.git", "p") -- project root marker → project name "harbor"
vim.fn.mkdir(proj .. "/internal/server", "p")

local today = os.date("%Y-%m-%d")
local soon = os.date("%Y-%m-%d", os.time() + 3 * 86400)

-- Demo code file: valid, gopls-quiet Go so no diagnostics pollute the shots.
vim.fn.writefile({ "module harbor", "", "go 1.22" }, proj .. "/go.mod")
vim.fn.writefile({
  "package server",
  "",
  'import "net"',
  "",
  "type Server struct{}",
  "",
  "func (s *Server) handleConn(c net.Conn) error {",
  "\tbuf := make([]byte, 4096)",
  "\tfor {",
  "\t\tn, err := c.Read(buf)",
  "\t\tif err != nil {",
  "\t\t\treturn err",
  "\t\t}",
  "\t\ts.dispatch(buf[:n])",
  "\t}",
  "}",
  "",
  "func (s *Server) dispatch(_ []byte) {}",
  "",
  "func Serve(l net.Listener, s *Server) error {",
  "\tfor {",
  "\t\tc, err := l.Accept()",
  "\t\tif err != nil {",
  "\t\t\treturn err",
  "\t\t}",
  "\t\tgo s.handleConn(c)",
  "\t}",
  "}",
}, proj .. "/internal/server/conn.go")

-- Project todo file: moorings, due dates, done + cancelled states.
vim.fn.writefile({
  "# harbor",
  "",
  "- [ ] handle EOF without dropping the conn · `internal/server/conn.go:11`",
  "- [ ] backpressure when dispatch is slow · `internal/server/conn.go:14`",
  "- [ ] release checklist due:" .. soon,
  "- [ ] rotate the TLS cert due:2026-08-15",
  "- [x] wire up graceful shutdown",
  "- [-] support HTTP/1.0 keep-alive",
}, vault .. "/todo/harbor.md")

-- Notes with wikilinks for the dashboard + backlinks shots.
vim.fn.writefile({
  "# Ideas",
  "",
  "- [ ] sketch the [[Connection lifecycle]] diagram",
  "- [ ] compare [[Backpressure strategies]] · notes first due:" .. today,
}, vault .. "/Ideas.md")
vim.fn.writefile({ "# Connection lifecycle", "", "accept → serve → drain." }, vault .. "/Connection lifecycle.md")
vim.fn.writefile({ "# Backpressure strategies", "", "bounded queues beat heroics." }, vault .. "/Backpressure strategies.md")

require("moor").setup(vim.tbl_deep_extend("force", require("moor").options, { notes_dir = vault }))
vim.cmd.cd(proj)
vim.cmd.edit(proj .. "/internal/server/conn.go")

print(table.concat({
  "moor demo staged (vault: " .. vault .. ", project: " .. proj .. ")",
  "",
  "Shot list — save each as assets/<name>.png:",
  "  1. capture.png          <leader>nT here, type 'handle EOF without dropping the conn'",
  "                          (screenshot BEFORE :w — abandon with <C-c> after)",
  "  2. mooring.png          this file: ⚓ signs are on lines 11 and 14",
  "  3. dashboard.png        <leader>nd (grouped view, links + due dates visible)",
  "  4. dashboard-sorted.png press s inside the dashboard (flat, by due)",
  "  5. project-view.png     q, then <leader>no (✓ strikethrough + ✗ cancelled)",
  "",
  "Restart nvim afterwards to get your real vault back.",
}, "\n"))
