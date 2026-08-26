local config = require("denim.config")
local cal    = require("denim.calendar")
local utils  = require("denim.utils")

describe("calendar", function()
  local dir

  local function find_float()
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_config(w).relative ~= "" then return w end
    end
  end

  local function close_all_floats()
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_config(w).relative ~= "" then
        pcall(vim.api.nvim_win_close, w, true)
      end
    end
  end

  local function n_callback(buf, lhs)
    local target = vim.api.nvim_replace_termcodes(lhs, true, false, true)
    for _, km in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
      if vim.api.nvim_replace_termcodes(km.lhs, true, false, true) == target then
        return km.callback
      end
    end
  end

  local function press(buf, lhs)
    local cb = n_callback(buf, lhs)
    assert.truthy(cb, "missing keymap: " .. lhs)
    cb()
  end

  local function title_text(win)
    local t = vim.api.nvim_win_get_config(win).title
    if type(t) ~= "table" then return t or "" end
    local parts = {}
    for _, line in ipairs(t) do
      if type(line) == "table" then
        for _, s in ipairs(line) do parts[#parts + 1] = s end
      else
        parts[#parts + 1] = line
      end
    end
    return table.concat(parts)
  end

  local function fmt(y, m, d)
    return string.format("%04d-%02d-%02d", y, m, d)
  end

  local function today_t()
    local t = os.date("*t")
    return t.year, t.month, t.day
  end

  local function open_calendar()
    cal.open()
    local win = find_float()
    assert.truthy(win, "expected a calendar floating window")
    return win, vim.api.nvim_win_get_buf(win)
  end

  before_each(function()
    dir = vim.fn.tempname()
    vim.fn.mkdir(dir, "p")
    config.setup({ notes_dir = dir })
  end)

  after_each(function()
    close_all_floats()
    vim.o.sidescrolloff = 0
    vim.o.scrolloff = 0
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      local name = vim.api.nvim_buf_get_name(b)
      if name ~= "" and name:find(dir, 1, true) then
        pcall(vim.api.nvim_buf_delete, b, { force = true })
      end
    end
    vim.fn.delete(dir, "rf")
  end)

  it("opens a floating window preselected to today", function()
    local win = open_calendar()
    local ty, tm, td = today_t()
    assert.truthy(title_text(win):find(fmt(ty, tm, td), 1, true),
      "title should show today, got: " .. title_text(win))
  end)

  it("places the cursor on today's cell", function()
    local win = open_calendar()
    local ty, tm, td = today_t()
    local grid = utils.month_grid(ty, tm, 1)
    local row, col
    for ri, week in ipairs(grid.weeks) do
      for ci = 1, 7 do
        if week[ci] == td then
          row, col = grid.first_cell_row + ri - 1, (ci - 1) * 3
        end
      end
    end
    assert.truthy(row, "today not found in grid")
    assert.same({ row, col }, { vim.api.nvim_win_get_cursor(win)[1], vim.api.nvim_win_get_cursor(win)[2] })
  end)

  it("Enter creates today's daily note and closes the calendar", function()
    local win, buf = open_calendar()
    press(buf, "<CR>")
    local expected = dir .. "/" .. os.date("%Y%m%d") .. "T000000--__daily.md"
    assert.truthy(vim.wait(500, function() return vim.fn.filereadable(expected) == 1 end, 10),
      "daily note not created")
    assert.equal(expected, vim.fn.expand("%:p"))
    assert.falsy(vim.api.nvim_win_is_valid(win), "calendar should close after Enter")
  end)

  it("Enter reopens an existing daily note without overwriting it", function()
    local expected = dir .. "/" .. os.date("%Y%m%d") .. "T000000--__daily.md"
    vim.fn.writefile({ "# DAILY", "", "keep this content" }, expected)
    local win, buf = open_calendar()
    press(buf, "<CR>")
    assert.truthy(vim.wait(500, function() return vim.fn.expand("%:p") == expected end, 10))
    assert.equal("keep this content", vim.fn.readfile(expected)[3])
    assert.falsy(vim.api.nvim_win_is_valid(win))
  end)

  it("moving right then Enter creates tomorrow's note", function()
    local win, buf = open_calendar()
    press(buf, "l")
    press(buf, "<CR>")
    local ty, tm, td = today_t()
    local y, m, d = utils.add_days(ty, tm, td, 1)
    local expected = dir .. "/" .. fmt(y, m, d):gsub("-", "") .. "T000000--__daily.md"
    assert.truthy(vim.wait(500, function() return vim.fn.filereadable(expected) == 1 end, 10),
      "tomorrow's daily note not created")
    assert.equal(expected, vim.fn.expand("%:p"))
    assert.falsy(vim.api.nvim_win_is_valid(win))
  end)

  it("moving down jumps 7 days", function()
    local win, buf = open_calendar()
    press(buf, "j")
    local ty, tm, td = today_t()
    local y, m, d = utils.add_days(ty, tm, td, 7)
    assert.truthy(title_text(win):find(fmt(y, m, d), 1, true))
  end)

  it("wraps past the month end and back", function()
    local win, buf = open_calendar()
    local ty, tm, td = today_t()
    local dim = utils.days_in_month(ty, tm)
    for _ = 1, (dim - td) do press(buf, "l") end
    assert.truthy(title_text(win):find(fmt(ty, tm, dim), 1, true))
    press(buf, "l")
    local ny, nm = utils.add_months(ty, tm, td, 1)
    assert.truthy(title_text(win):find(fmt(ny, nm, 1), 1, true))
    press(buf, "h")
    assert.truthy(title_text(win):find(fmt(ty, tm, dim), 1, true))
  end)

  it("<C-n> and <C-p> switch months keeping the day", function()
    local win, buf = open_calendar()
    local ty, tm, td = today_t()
    local y, m, d = utils.add_months(ty, tm, td, 1)
    press(buf, "<C-n>")
    assert.truthy(title_text(win):find(fmt(y, m, d), 1, true))
    press(buf, "<C-p>")
    assert.truthy(title_text(win):find(fmt(ty, tm, td), 1, true))
  end)

  it("t jumps back to today after navigating", function()
    local win, buf = open_calendar()
    press(buf, "l")
    press(buf, "j")
    press(buf, "t")
    local ty, tm, td = today_t()
    assert.truthy(title_text(win):find(fmt(ty, tm, td), 1, true))
  end)

  it("q closes without creating a file", function()
    local win, buf = open_calendar()
    press(buf, "q")
    assert.falsy(vim.api.nvim_win_is_valid(win))
    assert.same({}, vim.fn.glob(dir .. "/*.md", false, true))
  end)

  it("respects a configured Sunday start weekday", function()
    config.setup({ notes_dir = dir, calendar = { start_weekday = 7 } })
    local _, buf = open_calendar()
    local line2 = vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1]
    assert.truthy(line2:find("^Su ", 1, false), "header should start with Sunday")
    assert.falsy(line2:find("^Mo ", 1, false))
  end)

  it("keeps content stationary when a large sidescrolloff is configured", function()
    vim.o.sidescrolloff = 8
    vim.o.scrolloff = 4
    local win, buf = open_calendar()
    assert.equal(0, vim.wo[win].sidescrolloff)
    assert.equal(0, vim.wo[win].scrolloff)
    local reached_edge = false
    for _ = 1, 40 do
      press(buf, "l")
      local col = vim.api.nvim_win_get_cursor(win)[2]
      local leftcol = vim.api.nvim_win_call(win, function()
        return vim.fn.winsaveview().leftcol
      end)
      if col >= 15 then
        reached_edge = true
        assert.equal(0, leftcol, "content should not scroll while moving right")
        break
      end
    end
    assert.truthy(reached_edge, "test never reached the right edge of the grid")
  end)
end)
