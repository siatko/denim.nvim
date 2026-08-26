local utils = require("denim.utils")

describe("slugify_title", function()
  it("lowercases input", function()
    assert.equal("hello", utils.slugify_title("Hello"))
  end)

  it("replaces spaces with hyphens", function()
    assert.equal("hello-world", utils.slugify_title("hello world"))
  end)

  it("collapses multiple spaces", function()
    assert.equal("hello-world", utils.slugify_title("hello   world"))
  end)

  it("removes special characters", function()
    assert.equal("hello-world", utils.slugify_title("hello, world!"))
  end)

  it("strips leading and trailing hyphens", function()
    assert.equal("hello", utils.slugify_title("-hello-"))
  end)

  it("collapses multiple hyphens", function()
    assert.equal("hello-world", utils.slugify_title("hello--world"))
  end)

  it("handles mixed case and symbols", function()
    assert.equal("fix-login-bug", utils.slugify_title("Fix Login Bug!"))
  end)

  it("returns empty string for all-special-character input", function()
    assert.equal("", utils.slugify_title("!!!"))
  end)

  it("preserves german umlauts", function()
    assert.equal("meine-überlegungen", utils.slugify_title("Meine Überlegungen"))
  end)

  it("preserves mixed umlaut and ascii", function()
    assert.equal("käse-und-brot", utils.slugify_title("Käse und Brot"))
  end)

  it("preserves eszett", function()
    assert.equal("straße", utils.slugify_title("Straße"))
  end)
end)

describe("link_text", function()
  it("uppercases a heading title", function()
    assert.equal("FIX LOGIN BUG", utils.link_text("Fix Login Bug"))
  end)

  it("converts filename slug dashes to spaces and uppercases", function()
    assert.equal("FIX LOGIN BUG", utils.link_text("fix-login-bug"))
  end)

  it("stays uppercase for an already-uppercase title", function()
    assert.equal("TARGET NOTE", utils.link_text("TARGET NOTE"))
  end)
end)

describe("slugify_tag", function()
  it("lowercases input", function()
    assert.equal("lua", utils.slugify_tag("Lua"))
  end)

  it("replaces spaces with underscores", function()
    assert.equal("my_tag", utils.slugify_tag("my tag"))
  end)

  it("replaces hyphens with underscores", function()
    assert.equal("my_tag", utils.slugify_tag("my-tag"))
  end)

  it("collapses multiple underscores", function()
    assert.equal("my_tag", utils.slugify_tag("my__tag"))
  end)

  it("removes special characters", function()
    assert.equal("mytag", utils.slugify_tag("my@tag!"))
  end)

  it("strips leading and trailing underscores", function()
    assert.equal("tag", utils.slugify_tag("_tag_"))
  end)

  it("returns empty string for empty input", function()
    assert.equal("", utils.slugify_tag(""))
  end)

  it("returns empty string for all-special-character input", function()
    assert.equal("", utils.slugify_tag("@#$%"))
  end)

  it("preserves german umlauts", function()
    assert.equal("notiz_über_käse", utils.slugify_tag("Notiz über Käse"))
  end)

  it("preserves eszett", function()
    assert.equal("fußball", utils.slugify_tag("Fußball"))
  end)
end)

describe("tags_from_filename", function()
  it("returns empty table when no tags", function()
    assert.same({}, utils.tags_from_filename("20260514--my-note.md"))
  end)

  it("returns single tag", function()
    assert.same({ "lua" }, utils.tags_from_filename("20260514--my-note__lua.md"))
  end)

  it("returns multiple tags", function()
    assert.same({ "pkm", "writing" }, utils.tags_from_filename("20260514--my-note__pkm_writing.md"))
  end)

  it("returns empty table for filename with no extension match", function()
    assert.same({}, utils.tags_from_filename("notanotefile.txt"))
  end)

  it("handles datetime-format filenames", function()
    assert.same({ "lua" }, utils.tags_from_filename("20260515T143022--my-note__lua.md"))
  end)

  it("returns todo tag from todo filename", function()
    assert.same({ "backend", "todo" }, utils.tags_from_filename("20260514--fix-bug__backend_todo.md"))
  end)

  it("returns done tag from done filename", function()
    assert.same({ "done", "work" }, utils.tags_from_filename("20260514--fix-bug__done_work.md"))
  end)
end)

describe("title_from_filename", function()
  it("extracts the slug between -- and __", function()
    assert.equal("fix-login-bug", utils.title_from_filename("20260514T143022--fix-login-bug__todo.md"))
  end)

  it("extracts the slug when there are no tags", function()
    assert.equal("my-note", utils.title_from_filename("20260514--my-note.md"))
  end)

  it("returns empty string for filenames without a slug", function()
    assert.equal("", utils.title_from_filename("notanotefile.txt"))
  end)

  it("returns empty string for daily notes with no title", function()
    assert.equal("", utils.title_from_filename("20260514T000000--__daily.md"))
  end)
end)

describe("relative_path", function()
  it("same directory", function()
    assert.equal("note.md", utils.relative_path("/notes/inbox", "/notes/inbox/note.md"))
  end)

  it("sibling directory", function()
    assert.equal("../zettel/note.md", utils.relative_path("/notes/inbox", "/notes/zettel/note.md"))
  end)

  it("parent to child", function()
    assert.equal("inbox/note.md", utils.relative_path("/notes", "/notes/inbox/note.md"))
  end)

  it("child to parent", function()
    assert.equal("../note.md", utils.relative_path("/notes/inbox", "/notes/note.md"))
  end)

  it("deeply nested sibling", function()
    assert.equal("../../b/c/note.md", utils.relative_path("/a/x/y", "/a/b/c/note.md"))
  end)
end)

describe("rename_tag_in_filename", function()
  it("renames a single tag", function()
    local f, ok = utils.rename_tag_in_filename("20260101--note__foo.md", "foo", "bar")
    assert.is_true(ok)
    assert.equal("20260101--note__bar.md", f)
  end)

  it("renames one tag among many, keeps others sorted", function()
    local f, ok = utils.rename_tag_in_filename("20260101--note__apple_foo_zebra.md", "foo", "mango")
    assert.is_true(ok)
    assert.equal("20260101--note__apple_mango_zebra.md", f)
  end)

  it("returns false when tag is not present", function()
    local f, ok = utils.rename_tag_in_filename("20260101--note__foo.md", "bar", "baz")
    assert.is_false(ok)
    assert.equal("20260101--note__foo.md", f)
  end)

  it("returns false for filename with no tags", function()
    local f, ok = utils.rename_tag_in_filename("20260101--note.md", "foo", "bar")
    assert.is_false(ok)
    assert.equal("20260101--note.md", f)
  end)

  it("removes tag when new_tag is empty string", function()
    local f, ok = utils.rename_tag_in_filename("20260101--note__foo_bar.md", "foo", "")
    assert.is_true(ok)
    assert.equal("20260101--note__bar.md", f)
  end)

  it("drops tag section entirely when last tag is removed", function()
    local f, ok = utils.rename_tag_in_filename("20260101--note__foo.md", "foo", "")
    assert.is_true(ok)
    assert.equal("20260101--note.md", f)
  end)

  it("deduplicates when new tag already exists", function()
    local f, ok = utils.rename_tag_in_filename("20260101--note__bar_foo.md", "foo", "bar")
    assert.is_true(ok)
    assert.equal("20260101--note__bar.md", f)
  end)

  it("renames todo tag to done tag", function()
    local f, ok = utils.rename_tag_in_filename("20260101--fix-bug__backend_todo.md", "todo", "done")
    assert.is_true(ok)
    assert.equal("20260101--fix-bug__backend_done.md", f)
  end)

  it("renames done tag back to todo tag", function()
    local f, ok = utils.rename_tag_in_filename("20260101--fix-bug__done_work.md", "done", "todo")
    assert.is_true(ok)
    assert.equal("20260101--fix-bug__todo_work.md", f)
  end)
end)

describe("add_tag_to_filename", function()
  it("adds tag to a file with no existing tags", function()
    local f, ok = utils.add_tag_to_filename("20260101--note.md", "todo")
    assert.is_true(ok)
    assert.equal("20260101--note__todo.md", f)
  end)

  it("adds tag sorted among existing tags", function()
    local f, ok = utils.add_tag_to_filename("20260101--note__work.md", "done")
    assert.is_true(ok)
    assert.equal("20260101--note__done_work.md", f)
  end)

  it("inserts tag in alphabetical order", function()
    local f, ok = utils.add_tag_to_filename("20260101--note__alpha_zebra.md", "mango")
    assert.is_true(ok)
    assert.equal("20260101--note__alpha_mango_zebra.md", f)
  end)

  it("returns false when tag already present", function()
    local f, ok = utils.add_tag_to_filename("20260101--note__todo_work.md", "todo")
    assert.is_false(ok)
    assert.equal("20260101--note__todo_work.md", f)
  end)

  it("returns false for non-md files", function()
    local f, ok = utils.add_tag_to_filename("20260101--diagram.png", "todo")
    assert.is_false(ok)
    assert.equal("20260101--diagram.png", f)
  end)
end)

describe("remove_tag_from_filename", function()
  it("removes the only tag, leaving no tag suffix", function()
    local f, ok = utils.remove_tag_from_filename("20260101--note__todo.md", "todo")
    assert.is_true(ok)
    assert.equal("20260101--note.md", f)
  end)

  it("removes one tag while keeping others", function()
    local f, ok = utils.remove_tag_from_filename("20260101--note__backend_todo.md", "todo")
    assert.is_true(ok)
    assert.equal("20260101--note__backend.md", f)
  end)

  it("removes tag from middle of list", function()
    local f, ok = utils.remove_tag_from_filename("20260101--note__alpha_done_zebra.md", "done")
    assert.is_true(ok)
    assert.equal("20260101--note__alpha_zebra.md", f)
  end)

  it("returns false when tag not present", function()
    local f, ok = utils.remove_tag_from_filename("20260101--note__work.md", "todo")
    assert.is_false(ok)
    assert.equal("20260101--note__work.md", f)
  end)

  it("returns false for files with no tags", function()
    local f, ok = utils.remove_tag_from_filename("20260101--note.md", "todo")
    assert.is_false(ok)
    assert.equal("20260101--note.md", f)
  end)
end)

describe("resolve_slug", function()
  it("preserves current slug when name is empty", function()
    assert.equal("my-note", utils.resolve_slug("", "My Note", "my-note"))
  end)

  it("preserves current slug when name matches title exactly", function()
    assert.equal("my-note", utils.resolve_slug("My Note", "My Note", "my-note"))
  end)

  it("preserves current slug when name matches title in different case", function()
    assert.equal("my-note", utils.resolve_slug("my note", "My Note", "my-note"))
  end)

  it("preserves current slug when name is lowercase of title (default prompt value)", function()
    assert.equal("my-note", utils.resolve_slug("my note", "My Note", "my-note"))
  end)

  it("slugifies new name when it differs from current title", function()
    assert.equal("new-name", utils.resolve_slug("New Name", "My Note", "my-note"))
  end)

  it("slugifies new name when only partially matching title", function()
    assert.equal("my-note-updated", utils.resolve_slug("My Note Updated", "My Note", "my-note"))
  end)
end)

describe("multiterm_match", function()
  -- empty prompt
  it("matches everything when prompt is empty", function()
    assert.is_true(utils.multiterm_match("", "20260101--some-note__rust.md"))
  end)

  it("matches everything when prompt is only spaces", function()
    assert.is_true(utils.multiterm_match("   ", "20260101--some-note__rust.md"))
  end)

  -- single term
  it("matches when single term is present", function()
    assert.is_true(utils.multiterm_match("rust", "20260101--some-note__rust.md"))
  end)

  it("does not match when single term is absent", function()
    assert.is_false(utils.multiterm_match("python", "20260101--some-note__rust.md"))
  end)

  -- Denote filename conventions
  it("matches tag by _tag prefix", function()
    assert.is_true(utils.multiterm_match("_rust", "20260101--some-note__rust_journal.md"))
  end)

  it("does not match absent tag by _tag prefix", function()
    assert.is_false(utils.multiterm_match("_python", "20260101--some-note__rust_journal.md"))
  end)

  it("matches slug by -- prefix", function()
    assert.is_true(utils.multiterm_match("--some-note", "20260101--some-note__rust.md"))
  end)

  it("does not match absent slug by -- prefix", function()
    assert.is_false(utils.multiterm_match("--other-note", "20260101--some-note__rust.md"))
  end)

  -- multi-term AND
  it("matches when all terms are present", function()
    assert.is_true(utils.multiterm_match("rust journal", "20260101--my-journal__rust_journal.md"))
  end)

  it("does not match when first term is absent", function()
    assert.is_false(utils.multiterm_match("python journal", "20260101--my-journal__rust_journal.md"))
  end)

  it("does not match when second term is absent", function()
    assert.is_false(utils.multiterm_match("rust python", "20260101--my-journal__rust_journal.md"))
  end)

  it("does not match when all terms are absent", function()
    assert.is_false(utils.multiterm_match("python elixir", "20260101--my-journal__rust_journal.md"))
  end)

  -- orderless: terms in any order
  it("matches terms regardless of order in prompt", function()
    local filename = "20260101--my-journal__rust_journal.md"
    assert.is_true(utils.multiterm_match("rust journal", filename))
    assert.is_true(utils.multiterm_match("journal rust", filename))
  end)

  -- three terms
  it("matches when three terms are all present", function()
    assert.is_true(utils.multiterm_match("_rust _journal 2026", "20260101--my-journal__rust_journal.md"))
  end)

  it("does not match when one of three terms is absent", function()
    assert.is_false(utils.multiterm_match("_rust _journal 2025", "20260101--my-journal__rust_journal.md"))
  end)

  -- mixing tag and slug search
  it("matches mixed tag and slug terms", function()
    assert.is_true(utils.multiterm_match("_rust --my-journal", "20260101--my-journal__rust.md"))
  end)

  it("does not match when tag term present but slug term absent", function()
    assert.is_false(utils.multiterm_match("_rust --other", "20260101--my-journal__rust.md"))
  end)

  -- plain matching: special pattern chars treated as literals
  it("treats dots as literal characters", function()
    assert.is_true(utils.multiterm_match(".md", "20260101--note__rust.md"))
  end)

  it("treats hyphens as literal characters", function()
    assert.is_true(utils.multiterm_match("my-journal", "20260101--my-journal__rust.md"))
  end)

  -- whitespace handling
  it("handles multiple spaces between terms", function()
    assert.is_true(utils.multiterm_match("rust   journal", "20260101--my-journal__rust_journal.md"))
  end)

  it("handles leading and trailing spaces", function()
    assert.is_true(utils.multiterm_match("  rust  ", "20260101--my-journal__rust_journal.md"))
  end)

  -- todo/done tag matching
  it("matches files with todo tag", function()
    assert.is_true(utils.multiterm_match("_backend _todo", "20260101--fix-bug__backend_todo.md"))
  end)

  it("matches files with done tag", function()
    assert.is_true(utils.multiterm_match("_backend _done", "20260101--fix-bug__backend_done.md"))
  end)

  -- timestamp matching
  it("matches by year", function()
    assert.is_true(utils.multiterm_match("2026 _rust", "20260101--note__rust.md"))
  end)

  it("does not match wrong year", function()
    assert.is_false(utils.multiterm_match("2025 _rust", "20260101--note__rust.md"))
  end)

  -- case sensitivity
  it("is case-sensitive", function()
    assert.is_false(utils.multiterm_match("Rust", "20260101--note__rust.md"))
    assert.is_true(utils.multiterm_match("rust", "20260101--note__rust.md"))
  end)

  -- no false positives on partial tag names
  it("_rust matches _rusty (substring - expected behaviour)", function()
    assert.is_true(utils.multiterm_match("_rust", "20260101--note__rusty.md"))
  end)

  it("_rusty does not match _rust only file", function()
    assert.is_false(utils.multiterm_match("_rusty", "20260101--note__rust.md"))
  end)
end)

describe("find_link_path", function()
  local line = "see [Alpha](alpha.md) and [Beta](beta.md) for details"

  it("returns path when cursor is on link text", function()
    assert.equal("alpha.md", utils.find_link_path(line, 6))
  end)

  it("returns path when cursor is on link url", function()
    assert.equal("alpha.md", utils.find_link_path(line, 16))
  end)

  it("returns path when cursor is on closing paren", function()
    assert.equal("alpha.md", utils.find_link_path(line, 21))
  end)

  it("returns nearest link when cursor is before all links", function()
    assert.equal("alpha.md", utils.find_link_path(line, 1))
  end)

  it("returns nearest link when cursor is after all links", function()
    assert.equal("beta.md", utils.find_link_path(line, #line))
  end)

  it("returns nearest link when cursor is between two links", function()
    -- cursor at 'a' in 'and', closer to Beta
    assert.equal("beta.md", utils.find_link_path(line, 27))
  end)

  it("returns nil when line has no links", function()
    assert.is_nil(utils.find_link_path("no links here", 1))
  end)

  it("returns the only link on a line regardless of cursor position", function()
    assert.equal("note.md", utils.find_link_path("- [ ] [My Note](note.md)", 1))
    assert.equal("note.md", utils.find_link_path("- [ ] [My Note](note.md)", 3))
  end)

  it("returns path from image link syntax", function()
    assert.equal("diagram.png", utils.find_link_path("see ![Diagram](diagram.png) here", 6))
  end)
end)

describe("days_in_month", function()
  it("returns 31 for January", function()
    assert.equal(31, utils.days_in_month(2026, 1))
  end)

  it("returns 28 for February in a non-leap year", function()
    assert.equal(28, utils.days_in_month(2026, 2))
  end)

  it("returns 29 for February in a leap year", function()
    assert.equal(29, utils.days_in_month(2024, 2))
  end)

  it("returns 28 for February in a century non-leap year", function()
    assert.equal(28, utils.days_in_month(1900, 2))
  end)

  it("returns 29 for February in a century leap year", function()
    assert.equal(29, utils.days_in_month(2000, 2))
  end)

  it("returns 30 for April", function()
    assert.equal(30, utils.days_in_month(2026, 4))
  end)
end)

describe("day_of_week", function()
  it("returns 1 (Monday) for 2024-01-01", function()
    assert.equal(1, utils.day_of_week(2024, 1, 1))
  end)

  it("returns 3 (Wednesday) for 2026-08-26", function()
    assert.equal(3, utils.day_of_week(2026, 8, 26))
  end)

  it("returns 6 (Saturday) for 2000-01-01", function()
    assert.equal(6, utils.day_of_week(2000, 1, 1))
  end)

  it("returns 7 (Sunday) for 2026-03-01", function()
    assert.equal(7, utils.day_of_week(2026, 3, 1))
  end)

  it("returns 7 (Sunday) for 2023-01-01", function()
    assert.equal(7, utils.day_of_week(2023, 1, 1))
  end)
end)

describe("add_days", function()
  it("returns the same date for delta 0", function()
    assert.same({ 2026, 8, 26 }, { utils.add_days(2026, 8, 26, 0) })
  end)

  it("adds within a month", function()
    assert.same({ 2026, 8, 31 }, { utils.add_days(2026, 8, 26, 5) })
  end)

  it("rolls into the next month", function()
    assert.same({ 2026, 9, 1 }, { utils.add_days(2026, 8, 31, 1) })
  end)

  it("rolls into the next year", function()
    assert.same({ 2027, 1, 1 }, { utils.add_days(2026, 12, 31, 1) })
  end)

  it("rolls back into the previous month", function()
    assert.same({ 2026, 7, 31 }, { utils.add_days(2026, 8, 1, -1) })
  end)

  it("rolls back into the previous year", function()
    assert.same({ 2025, 12, 31 }, { utils.add_days(2026, 1, 1, -1) })
  end)

  it("crosses a leap-year February", function()
    assert.same({ 2024, 2, 29 }, { utils.add_days(2024, 2, 28, 1) })
    assert.same({ 2024, 3, 1 }, { utils.add_days(2024, 2, 29, 1) })
  end)
end)

describe("add_months", function()
  it("returns the same month for delta 0", function()
    assert.same({ 2026, 8, 26 }, { utils.add_months(2026, 8, 26, 0) })
  end)

  it("moves to the next month keeping the day", function()
    assert.same({ 2026, 9, 26 }, { utils.add_months(2026, 8, 26, 1) })
  end)

  it("clamps to the last day of the target month", function()
    assert.same({ 2026, 2, 28 }, { utils.add_months(2026, 1, 31, 1) })
    assert.same({ 2024, 2, 29 }, { utils.add_months(2024, 1, 31, 1) })
  end)

  it("rolls into the next year", function()
    assert.same({ 2027, 1, 15 }, { utils.add_months(2026, 12, 15, 1) })
  end)

  it("rolls back into the previous year", function()
    assert.same({ 2025, 12, 15 }, { utils.add_months(2026, 1, 15, -1) })
  end)
end)

describe("date_raw", function()
  it("zero-pads month and day", function()
    assert.equal("20260305", utils.date_raw(2026, 3, 5))
  end)

  it("keeps double-digit month and day", function()
    assert.equal("20261231", utils.date_raw(2026, 12, 31))
  end)
end)

describe("month_grid", function()
  it("centers the month title on the first line", function()
    local g = utils.month_grid(2026, 8, 1)
    assert.equal("     August 2026     ", g.lines[1])
  end)

  it("starts the weekday header on Monday by default", function()
    local g = utils.month_grid(2026, 8, 1)
    assert.equal("Mo Tu We Th Fr Sa Su ", g.lines[2])
  end)

  it("starts the weekday header on Sunday when configured", function()
    local g = utils.month_grid(2026, 8, 7)
    assert.equal("Su Mo Tu We Th Fr Sa ", g.lines[2])
  end)

  it("places August 2026's first day (Saturday) in column 6", function()
    local g = utils.month_grid(2026, 8, 1)
    assert.is_nil(g.weeks[1][1])
    assert.equal(1, g.weeks[1][6])
    assert.equal(2, g.weeks[1][7])
  end)

  it("places February 2026's first day (Sunday) in column 7", function()
    local g = utils.month_grid(2026, 2, 1)
    assert.equal(1, g.weeks[1][7])
  end)

  it("lays out every day of the month exactly once", function()
    local g = utils.month_grid(2026, 8, 1)
    local count = 0
    for _, week in ipairs(g.weeks) do
      for c = 1, 7 do
        if week[c] then count = count + 1 end
      end
    end
    assert.equal(31, count)
  end)

  it("produces a fixed width of 21 columns", function()
    local g = utils.month_grid(2026, 8, 1)
    assert.equal(21, g.width)
    for _, line in ipairs(g.lines) do
      assert.equal(21, #line)
    end
  end)

  it("marks the first week row as buffer row 3", function()
    local g = utils.month_grid(2026, 8, 1)
    assert.equal(3, g.first_cell_row)
    assert.equal(3 + #g.weeks - 1, #g.lines)
  end)
end)
