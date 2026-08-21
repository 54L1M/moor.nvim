# moor.nvim

Notes and todos, moored to your code.

> To _moor_ a boat is to tie it to a fixed point so it stays where you left it.
> moor.nvim does that with your thoughts: capture them without leaving the
> buffer, tie them to a `file:line`, and pull yourself back to that exact spot
> later.

moor is **not** an Obsidian or ZenNotes clone — it's meant to be used _with_
those apps, not instead of them. moor is the quick-capture lane while you
code; your notes app stays the place for reading, organizing, and everything
else. It shares exactly one concept with them — `[[backlinks]]` — and writes
plain, portable markdown. Point `notes_dir` at a vault that syncs (iCloud,
git, Syncthing) and your captures and todos show up on your phone; edits made
there flow back the next time moor scans.

---

## Requirements

- Neovim **0.11+**
- Nothing else.

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "54l1m/moor.nvim",
  opts = {
    notes_dir = "~/notes", -- your vault, e.g. an iCloud-synced ZenNotes folder
  },
}
```

## Configuration

```lua
require("moor").setup({
  notes_dir = "~/notes",
  ignore = { ".git", ".obsidian", "trash", "archive" }, -- dir names skipped by every scan

  capture = {
    -- Destination for note captures, relative to notes_dir. os.date() tokens
    -- are expanded: "inbox/%Y-%m-%d.md" turns captures into daily notes.
    note_file = "Captures.md",
    -- Heading above each capture, as an os.date() format. false = raw append.
    timestamp = "## %Y-%m-%d %H:%M",
    window = { width = 0.5, height = 0.3, border = "rounded", title = " moor " },
    maps = { promote = "<C-p>", abort = "<C-c>" }, -- inside the float only
  },

  todo = {
    dir = "todo",                 -- todos live in <notes_dir>/todo/<project>.md
    toggle_states = { " ", "x" }, -- add "-" for a cancelled state in the cycle
  },

  dashboard = {
    window = { width = 0.7, height = 0.7, border = "rounded", title = " open todos " },
    -- View-only; files keep "- [ ]" markdown. icons = false shows raw brackets.
    -- cancelled styles the "-" state (add it to todo.toggle_states to use it).
    icons = { open = "○", done = "✓", cancelled = "✗" },
    maps = { toggle = "t", jump = "<CR>", jump_context = "gd", sort = "s", refresh = "r", close = "q" },
  },

  links = {
    new_note_dir = "", -- where notes created from [[missing links]] land
  },

  -- Global keymaps, applied by setup(). Set keymaps = false to define none
  -- (and bind the API yourself), set one entry to false to skip just it, or
  -- give an entry a different lhs to rebind.
  keymaps = {
    capture_note = "<leader>nn",
    capture_todo = "<leader>nt",
    capture_todo_context = "<leader>nT",
    add_todo = "<leader>na",        -- prompt, moored to the cursor position
    add_todo_plain = "<leader>nA",  -- prompt, no file:line reference
    dashboard = "<leader>nd",
    toggle = "<leader>nx",
    follow_link = "<leader>nf",
    backlinks = "<leader>nb",
    open_todo = "<leader>no",
  },
})
```

---

## Features

### Capture

A thought hits while you're mid-function. Press your capture key: a small float
opens over the code, you type, `:w` — the float closes and you're back where
you were. That's the whole gesture.

- **note mode** appends to `capture.note_file` under a dated heading
  (`## 2026-08-21 12:32` by default — `capture.timestamp` takes any `os.date()`
  format, or `false`), creating the file with a `# Title` header so it renders
  properly in ZenNotes/Obsidian.
- **todo mode** turns each line into `- [ ] …` in your project's todo file.
- **context** (`capture({ mode = "todo", context = true })`) moors the todo to
  where your cursor was:

  ```markdown
  - [ ] handle EOF case · `internal/server/conn.go:142`
  ```

  On your phone that's just readable monospace. In nvim, it's a jump target.
  Works whether you type plain prose or a full `- [ ] …` line yourself — a
  hand-typed task without a mooring still gets one.

- **promote** (`<C-p>` inside the float) reopens the same buffer in a split
  when the thought turns out to be bigger than the float. `:w` still saves to
  the vault. `<C-c>` abandons.

`:Moor capture`, `:Moor capture todo`, `:Moor capture todo context`, or the
one-liner prompt `:Moor todo` (`<leader>na`) — moored by default; `:Moor todo
plain` skips the file:line.

### Todos

- One file per project: `<notes_dir>/todo/<project>.md`, where the project is
  your git root's name (cwd basename outside a repo). `:Moor open` shows the
  **project todo view** — the dashboard scoped to this project's file, with
  done tasks kept visible, struck through. `<CR>` opens the underlying file
  when you want to edit freely.
- `:Moor toggle` flips the checkbox on the current line — in any buffer,
  including inside the dashboard.
- **Due dates** are inline `due:YYYY-MM-DD` tokens — the syntax ZenNotes
  already parses, so they work on your phone too. When capturing you can type
  relative shortcuts and moor expands them to the absolute date on save:

  ```
  due:today  due:tomorrow  due:fri  due:monday  due:3d  due:2w
  ```

  The dashboard highlights the token; overdue and due-today dates get a
  warning accent.
- `:Moor dashboard` opens a float aggregating every open `- [ ]` across the
  vault, grouped by note:

  ```
   todo/pf4.md (2)
     ○ fix race in loader · `lua/moor/init.lua:33`
     ○ write vault spec
   inbox/Ideas.md (1)
     ○ try the capture float on the phone
  ```

  `<CR>` jumps to the note, `gd` jumps to the moored code location, `t`
  toggles (the item disappears — that's the feedback), `s` switches to a flat
  soonest-first deadline list (undated items last, source note dimmed at the
  end of each row) and back, `r` rescans, `q` closes. The active keys are
  pinned in the float's bottom border, and your global toggle binding works
  here too.

  The rendering is view-only sugar — wikilinks show without their
  `[[brackets]]`, checkboxes use the configured `dashboard.icons` — while the
  files on disk always keep plain markdown.

### Highlight groups

| Group          | Styles                     | Default                     |
| -------------- | -------------------------- | --------------------------- |
| `MoorLink`     | wikilink text in the views | `Underlined`                |
| `MoorDone`     | done task text             | strikethrough, `Comment` fg |
| `MoorDoneMark` | done checkbox icon         | `Comment`                   |
| `MoorTodoMark` | open checkbox icon         | unstyled                    |
| `MoorDue`      | future due dates           | `Special`                   |
| `MoorOverdue`  | overdue / due-today dates  | `DiagnosticError`           |

Change any of them in your config or colorscheme:

```lua
vim.api.nvim_set_hl(0, "MoorLink", { fg = "#7aa2f7" })
```

### Backlinks

- `:Moor follow` opens the `[[Note Title]]` under the cursor, offering to
  create the note when it doesn't exist yet.
- `:Moor backlinks` lists every note linking to the current one via
  `vim.ui.select` — `[[Title]]`, `[[Title|alias]]`, and `[[Title#heading]]`
  all count.

### Built for synced vaults

moor never caches your notes. Every scan re-reads the directory, unreadable
files (like evicted iCloud placeholders) are skipped silently, and toggling a
todo from the dashboard re-checks the source line first — if your phone edited
the note in the meantime, moor rescans instead of rewriting the wrong line.

---

## Plugin structure

```
moor.nvim/
├── lua/moor/
│   ├── init.lua       -- public API: defaults, options, setup()
│   ├── cmd.lua        -- :Moor subcommand dispatcher
│   ├── project.lua    -- project identity (git root / cwd)
│   ├── vault.lua      -- all notes_dir filesystem access
│   ├── tasks.lua      -- pure checkbox-line parse/toggle/format
│   ├── capture.lua    -- the capture float
│   ├── todo.lua       -- per-project todo operations
│   ├── dashboard.lua  -- the open-todo dashboard
│   ├── links.lua      -- wikilinks: follow + backlinks
│   ├── context.lua    -- file:line references
│   └── picker.lua     -- vim.ui.select seam (native adapters land here)
├── plugin/moor.lua    -- :Moor command (lazy, zero startup cost)
└── tests/             -- plenary busted specs, one per module
```

## Contributing

Contributions are welcome and encouraged — especially **picker adapters**:
every list UI goes through `lua/moor/picker.lua` (a thin `vim.ui.select`
wrapper), so a native telescope/fzf-lua/snacks/mini.pick adapter with previews
only needs to touch that one file.

```sh
make test          # run the suite (fetches plenary on first run)
make format        # stylua
make format-check
```

Conventional commits, tests for behavior changes, and `make format` before
pushing.

## License

MIT
