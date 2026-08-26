# denim.nvim

```
   o   o   o   o   o
  ___________________
 |                   |   denim.nvim
 | 20260514T143022-- |
 | my-note__pkm.md   |   no database.
 |                   |   no frontmatter.
 |  # MY NOTE        |   just a really
 |                   |   long filename.
 |  _______________  |
 |  _______________  |
 |  _______          |   yet another denote
 |                   |   plugin nobody asked for. 
 |___________________|
```

![Tests](https://github.com/siatko/denim.nvim/actions/workflows/test.yml/badge.svg)
![Neovim](https://img.shields.io/badge/Neovim-%3E%3D%200.10-57A143?logo=neovim)
![License](https://img.shields.io/github/license/siatko/denim.nvim)

> A [Denote](https://protesilaos.com/emacs/denote)-inspired note-taking plugin for Neovim.
> Plain markdown files, structured filenames, no database, no proprietary formats.

## Features

- **Flat structure** - all notes, todos, and attachments in one directory
- **Denote-style filenames** - `YYYYMMDDTHHMMSS--title__tag1_tag2.md`; the filename is the metadata - no frontmatter, no database
- **Full-text search** - live grep across all note contents
- **Note linking** - insert markdown links to other notes; follow with `<CR>` or ctrl+click; find all backlinks to the current note
- **Todo tracking** - todo/done as regular tags; cycle any note through none/todo/done with one key
- **Quick capture** - floating markdown editor that doesn't interrupt your current buffer; auto-tagged; template-aware
- **Templates** - create notes from `.md` files in `.templates/`; `$` marks tab stops; Tab steps through each one
- **Tag search** - browse all tags and filter notes by one or more; list untagged notes
- **Tag rename** - rename a tag across all notes in one step; all backlinks updated automatically
- **Refactor** - rename and retag the current note; all backlinks updated automatically
- **URL linking** - insert URL links from clipboard; `<CR>` and ctrl+click open the browser
- **File paste** - paste any file or image from clipboard with a denim filename
- **Notes index** - virtual buffer listing all notes grouped by date with todo status markers
- **Daily calendar** - floating month view preselected to today; move with `h/j/k/l`, page months with `<C-p>`/`<C-n>`, and `<CR>` opens or creates that day's daily note
- **Statistics** - note counts, tag usage, and monthly activity at a glance

## Requirements

- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [img-clip.nvim](https://github.com/HakonHarnes/img-clip.nvim) (optional, for pasting raw clipboard images)
- [which-key.nvim](https://github.com/folke/which-key.nvim) (optional, for keymap group labels)
- `ripgrep` (for content search)
- `find` (for file listing)

## Installation

**lazy.nvim:**

```lua
{
  "siatko/denim.nvim",
  event = "VeryLazy",
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "HakonHarnes/img-clip.nvim",
    "folke/which-key.nvim",
  },
  config = function()
    require("denim").setup({
      notes_dir = "~/notes",
    })
  end,
}
```

## Configuration

All keys are optional - only set what you want to override:

```lua
require("denim").setup({
  notes_dir = "~/notes",

  -- Tag names used for workflow states. All are configurable.
  -- capture: automatically applied to quick captures; a template named
  --   <capture>.md in .templates/ is used as the initial content if it exists.
  workflow = {
    todo    = "todo",
    done    = "done",
    capture = "quick",
    daily   = "daily",
  },

  -- First column of the daily calendar: 1 = Monday .. 7 = Sunday
  calendar = {
    start_weekday = 1,
  },

  keymaps = {
    -- basic
    new_note          = "<leader>nn",
    daily_note        = "<leader>nd", -- opens the daily note calendar
    capture           = "<leader>nq",
    search_notes      = "<leader>nf",
    search_content    = "<leader>ns",
    refactor          = "<leader>nr",
    paste_image       = "<leader>np",
    insert_link       = "<leader>nl",
    insert_url_link   = "<leader>nu",
    backlinks         = "<leader>nb",
    -- templates
    new_from_template = "<leader>ntn",
    new_template      = "<leader>ntN",
    search_templates  = "<leader>nte",
    -- tags
    search_tags       = "<leader>ngs",
    search_untagged   = "<leader>ngu",
    rename_tag        = "<leader>ngr",
    -- todos
    cycle_workflow    = "<leader>nx",
    -- views
    open_index        = "<leader>nvi",
    open_stats        = "<leader>nvs",
  },
})
```

## Keymaps

| Key | Action |
|---|---|
| `<leader>nn` | New note |
| `<leader>nd` | Open the daily note calendar (today preselected; `<CR>` opens/creates) |
| `<leader>nq` | Quick capture |
| `<leader>nf` | Find note by filename (multi-term) |
| `<leader>ns` | Search note contents (multi-term live grep) |
| `<leader>nr` | Refactor current note (rename + retag) |
| `<leader>np` | Paste file or image from clipboard |
| `<leader>nl` | Insert link to another note |
| `<leader>nu` | Insert URL link from clipboard |
| `<leader>nb` | Show backlinks to current note |
| `<leader>nx` | Cycle workflow state: none → todo → done → none |
| `<leader>ntn` | New note from template |
| `<leader>ntN` | New template |
| `<leader>nte` | Browse and edit templates |
| `<leader>ngs` | Browse and search tags |
| `<leader>ngu` | List notes without any tags |
| `<leader>ngr` | Rename a tag across all notes |
| `<leader>nvi` | Open notes index |
| `<leader>nvs` | Open notes statistics |
| `<CR>` | Follow markdown link (inside note files) |

## Daily Calendar

`<leader>nd` (or `:DenimCalendar`) opens a floating month view with **today preselected**. Pressing `<CR>` immediately opens or creates today's daily note — the same `YYYYMMDDT000000--__daily.md` as before. Use the keys below to jump around instead. `:DenimDaily` still opens today's daily note directly, without the calendar.

| Key | Action |
|---|---|
| `h` `j` `k` `l` / arrows | Move selection (wraps across months) |
| `<C-p>` / `<C-n>` | Previous / next month |
| `t` | Jump back to today |
| `<CR>` | Open or create the selected day's daily note |
| `q` / `<Esc>` | Close |

The first column defaults to Monday; set `calendar.start_weekday = 7` for a Sunday start.

## File Naming

denim follows the [Denote](https://protesilaos.com/emacs/denote) file naming convention, pioneered by Protesilaos Stavrou for Emacs. The core idea: **the filename is the metadata**. No frontmatter, no database, no proprietary format - just a name you can grep, sort, move, or open with any editor on any OS, forever.

Every filename is built from four parts:

```
20260514T143022--zettelkasten-intro__pkm_writing.md
│       │      │                   │
│       │      │                   └─ tags, separated by _
│       │      └─ -- separates timestamp from title
│       └─ T separates date from time
└─ YYYYMMDDTHHMMSS — unique timestamp, sorts chronologically
```

The timestamp makes every note unique even if you create two with the same title. The double-dash `--` and double-underscore `__` separators are unambiguous delimiters that survive any shell quoting, URL encoding, or overzealous autocorrect.

**Notes**
```
20260514T143022--zettelkasten-intro__pkm_writing.md
20260514T161500--meeting-notes.md
```

**Todos** — `todo` and `done` are regular tags, sorted alphabetically with all other tags; their position in the filename is not significant
```
20260514T143022--fix-login-bug__todo.md         (open, only tag)
20260514T143022--fix-login-bug__backend_todo.md (open, b < t so backend sorts first)
20260514T143022--fix-login-bug__done_work.md    (done, d < w so done sorts first)
20260514T143022--fix-login-bug__backend_done.md (done, b < d so backend sorts first)
```

**Attachments**
```
20260514T143022--architecture-diagram__pkm.png
```

## Searching

Both `<leader>nf` (filename) and `<leader>ns` (content) support **multi-term AND search**: separate terms with spaces and every term must match, in any order.

Because the filename is the metadata, the Denote naming convention doubles as a natural search syntax:

| Prefix | Matches | Example |
|---|---|---|
| `_` | tag | `_rust` - notes tagged rust; `_todo` - all open todos; `_done` - all done todos |
| `--` | title/slug | `--meeting` - notes with "meeting" in the title |
| none | anywhere | `2026` - matches timestamp, title, or tags |

Combine freely - `_rust _todo 2026` finds open todos from 2026 tagged rust. Order does not matter.

`<leader>nf` shows all notes immediately and filters as you type. `<leader>ns` requires at least one character before ripgrep runs - that is normal live-grep behaviour.

## Linking Philosophy

Denote (the Emacs plugin that inspired the filename format) uses ID-based links:

```
[[denote:20260514T143022]]
```

The ID never changes, so links never break - even after a rename. denim takes a different approach and uses standard markdown links pointing to the full filename:

```markdown
[My Note](20260514T143022--my-note__pkm.md)
```

This means denim has to rewrite backlinks whenever a file is renamed (which it does automatically). That is a small price to pay for a significant gain: your notes are **plain readable markdown** that works everywhere - GitHub, Obsidian, any static site generator, or a plain text editor - with no plugin needed to resolve links. ID-based links are opaque outside of Emacs and lock your notes to the tool that created them. denim's goal is the opposite: the plugin is a convenience layer, and your notes should outlive it.

## URL Links

`<leader>nu` (or `:DenimInsertUrlLink`) inserts a markdown link to an external URL at the cursor position. The URL prompt is pre-filled with the clipboard contents; the title prompt is empty.

```markdown
[My favourite video](https://youtube.com/watch?v=dQw4w9WgXcQ)
```

Pressing `<CR>` or ctrl+clicking on a URL link opens it in the browser via `xdg-open` instead of trying to follow it as a note file.

## Tag Workflow

Todo and done status are plain tags. The tag names default to `todo` and `done` but are fully configurable via the `workflow` option - for example GTD users might prefer `next`/`completed`:

```lua
require("denim").setup({
  workflow = {
    todo = "next",
    done = "completed",
  },
})
```

`<leader>nx` cycles the workflow state of the current note: no tag → todo → done → no tag. The index and statistics views respect the configured tag names throughout.

When creating a note or todo, a Telescope picker appears after entering the title. Use `<Tab>` to toggle existing tags. To add new tags, type one or more space-separated names and press `<Enter>` - the picker re-opens with all previously-selected and newly-typed tags pre-selected, so you can keep selecting or deselecting. Press `<Enter>` with an empty prompt to finalize. Press `<Esc>` at any point to cancel without creating the note.

`<leader>ngs` opens a search picker: selecting one or more tags filters to notes that carry all of them.

`<leader>ntn` opens a template picker showing all `.md` files from `notes_dir/.templates/`. After selecting, the usual title and tag prompts follow. The template's body is used as the note's initial content; an H1 heading in the template is replaced by the generated title. Templates are never shown in note search or content grep results. If `.templates/` is empty or missing, denim notifies and bails. Create a new template with `<leader>ntN` (prompts for a name, opens a blank buffer in `.templates/`). Browse and edit existing templates with `<leader>nte`.

Place `$` anywhere in a template to mark cursor stops. When the note opens, the cursor lands on the first `$` (which is deleted) in insert mode. Press `<Tab>` to jump to each subsequent `$`. Once all stops are visited `<Tab>` returns to its normal behavior.

```
## Meeting: $

Attendees: $

## Action items

- $
```

`<leader>ngu` opens a picker listing all notes that have no tags - useful for a quick tagging pass.

`<leader>ngr` opens a single-select tag picker. After selecting a tag, enter a new name and every file carrying that tag is renamed and every backlink pointing to any of those files is rewritten. A notification reports how many files were renamed and how many link references were updated.

## Quick Capture

`<leader>nq` (or `:DenimCapture`) lets you jot down a note without leaving your current buffer. A title prompt appears, then a floating markdown editor opens centered on screen:

```
╭─────────── 20260517T120000--my-thought__quick.md ───────────╮
│                                                              │
│                                                              │
│                                                              │
╰────────────── <C-s> save  Esc/q cancel ─────────────────────╯
```

Press `<C-s>` (insert or normal mode) to save and close. Press `Esc` or `q` in normal mode to cancel - no file is created. The note is auto-tagged with `workflow.capture` (default `quick`).

If a template named `<capture>.md` exists in `notes_dir/.templates/` (e.g. `quick.md`), it is used as the initial content of the float. Tab stops (`$`) work the same as in template-based note creation.

## Daily Notes

`<leader>nd` (or `:DenimDaily`) opens today's daily note, creating it if it doesn't exist yet. The filename uses today's date with the time zeroed out and an empty title - just the date and a tag:

```
20260826T000000--__daily.md
```

Each day gets exactly one daily note: pressing `<leader>nd` again later in the day reopens the same file instead of creating a duplicate. The tag is configurable via `workflow.daily` (default `daily`), so the tag name sorts first in searches alongside your other tags.

## Notes Index

`<leader>nvi` (or `:DenimIndex`) opens a virtual buffer listing all notes grouped by date, newest first:

```
# Notes Index

## 2026-05-14

- [ ] [Fix login bug](20260514--fix-login-bug__backend_todo.md)
- [Zettelkasten intro](20260514--zettelkasten-intro__pkm.md)

## 2026-05-13

- [x] [Write tests](20260513--write-tests__done.md)
```

| Key | Action |
|---|---|
| `<CR>` | Open the note under the cursor |
| `r` | Refresh the index |
| `q` | Close the index |

## Statistics

`<leader>nvs` (or `:DenimStats`) opens a virtual buffer with an overview of your notes:

```
# Notes Statistics

## Overview

  Total          42
  Notes          27
  Open todos      7
  Done todos      8
  Tags           23
  Linked         18  (43%)

## Activity

  This month      8
  Last month     14

## Top Tags

  pkm            12
  writing         8
  backend         6
```

| Key | Action |
|---|---|
| `r` | Refresh |
| `q` | Close |

## User Commands

| Command | Action |
|---|---|
| `:DenimCapture` | Quick capture |
| `:DenimNew` | New note |
| `:DenimDaily` | Open or create today's daily note |
| `:DenimNewFromTemplate` | New note from template |
| `:DenimNewTemplate` | Create a new template |
| `:DenimSearch` | Find notes by filename |
| `:DenimSearchContent` | Search note contents |
| `:DenimTags` | Search tags |
| `:DenimTemplates` | Browse and edit templates |
| `:DenimUntagged` | List notes without tags |
| `:DenimRenameTag` | Rename a tag across all notes |
| `:DenimInsertLink` | Insert link to another note |
| `:DenimInsertUrlLink` | Insert URL link from clipboard |
| `:DenimBacklinks` | Show backlinks to current note |
| `:DenimPasteImage` | Paste file or image from clipboard |
| `:DenimRefactor` | Refactor current note (rename + retag) |
| `:DenimCycle` | Cycle workflow state: none → todo → done → none |
| `:DenimIndex` | Open notes index |
| `:DenimStats` | Open notes statistics |

## Development

Clone the repo and point lazy.nvim at the local path:

```lua
{
  dir = "~/path/to/denim.nvim",
  event = "VeryLazy",
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "HakonHarnes/img-clip.nvim",
    "folke/which-key.nvim",
  },
  config = function()
    require("denim").setup({ notes_dir = "~/notes" })
  end,
}
```

Run the test suite from the project root (requires plenary.nvim):

```
make test
```

Tests cover pure helpers in `utils.lua`, the index line builder in `index.lua`, and integration tests for all user-facing operations.

## Contributing

PRs and issues are very welcome. One rule: **every change must be covered by tests.** This is the most important thing. Tests are what keep the plugin reliable as it grows, and no PR will be merged without them.

- Bug fix - **always** add a regression test that reproduces the bug before the fix. This is non-negotiable: a bug fix without a test is just a bug waiting to come back
- New feature in `notes.lua` - add integration specs in `tests/integration_spec.lua`
- New pure helper in `utils.lua` - add unit specs in `tests/utils_spec.lua`

Tests are run automatically on every push and pull request via GitHub Actions. You can run them locally with `make test` (requires plenary.nvim at `~/.local/share/nvim/lazy/plenary.nvim`).

See `CLAUDE.md` for a full overview of the architecture and testing conventions.

## A Note on How This Was Built

I'm a dad with a full-time job and approximately 45 minutes of free time per week. This plugin exists because I pair programmed it with [Claude Code](https://claude.ai/code) - which turns out to be a pretty good way to ship a Neovim plugin when your other option is waiting until your child moves out.

If you're using this plugin or thinking about contributing - you should know that. The ideas, design decisions, and direction are mine; Claude helped me get them out of my head and into working Lua faster than I could have alone. Issues and PRs are very welcome either way.

