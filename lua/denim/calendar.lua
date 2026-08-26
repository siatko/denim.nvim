local M = {}

local utils = require("denim.utils")

local buf  = nil
local win  = nil
local grid = nil
local state = { y = 0, m = 0, d = 0 }

local function get_opts()
  return require("denim.config").options
end

local function start_weekday()
  local sw = get_opts().calendar and get_opts().calendar.start_weekday or 1
  if sw < 1 or sw > 7 then sw = 1 end
  return sw
end

local function today()
  local t = os.date("*t")
  return { y = t.year, m = t.month, d = t.day }
end

local function cell_col(ci)
  return (ci - 1) * 3
end

local function position_for(grid, day)
  for ri, week in ipairs(grid.weeks) do
    for ci = 1, 7 do
      if week[ci] == day then
        return grid.first_cell_row + ri - 1, cell_col(ci)
      end
    end
  end
  return grid.first_cell_row, 0
end

local function selected_date_text()
  return string.format("%04d-%02d-%02d", state.y, state.m, state.d)
end

local function render()
  grid = utils.month_grid(state.y, state.m, start_weekday())

  vim.wo[win].wrap         = false
  vim.wo[win].scrolloff    = 0
  vim.wo[win].sidescrolloff = 0

  vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, grid.lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

  local row, col = position_for(grid, state.d)
  vim.api.nvim_win_set_cursor(win, { row, col })

  vim.api.nvim_win_set_config(win, {
    height = #grid.lines + 2,
    width  = grid.width + 2,
    title  = " " .. selected_date_text() .. " ",
    footer = "  h/j/k/l move · C-p/C-n month · t today · Enter open · q close  ",
  })

  local ns = vim.api.nvim_create_namespace("denim_calendar")
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local t = today()
  if state.y == t.y and state.m == t.m then
    local trow, tcol = position_for(grid, t.d)
    vim.api.nvim_buf_add_highlight(buf, ns, "Title", trow - 1, tcol, tcol + 2)
  end
end

local function move(delta)
  local y, m, d = utils.add_days(state.y, state.m, state.d, delta)
  state.y, state.m, state.d = y, m, d
  render()
end

local function change_month(delta)
  local y, m, d = utils.add_months(state.y, state.m, state.d, delta)
  state.y, state.m, state.d = y, m, d
  render()
end

local function goto_today()
  local t = today()
  state.y, state.m, state.d = t.y, t.m, t.d
  render()
end

local function close()
  local w, b = win, buf
  win, buf = nil, nil
  if w and vim.api.nvim_win_is_valid(w) then
    vim.api.nvim_win_close(w, true)
  end
  if b and vim.api.nvim_buf_is_valid(b) then
    pcall(vim.api.nvim_buf_delete, b, { force = true })
  end
end

local function select_day()
  local date_raw = utils.date_raw(state.y, state.m, state.d)
  close()
  require("denim.notes").daily_note(date_raw)
end

local function setup_keymaps(b)
  local function map(lhs, cb, desc)
    vim.keymap.set("n", lhs, cb, { buffer = b, nowait = true, desc = "denim: calendar " .. desc })
  end
  map("h",       function() move(-1) end, "move left")
  map("l",       function() move(1) end, "move right")
  map("k",       function() move(-7) end, "move up")
  map("j",       function() move(7) end, "move down")
  map("<Left>",  function() move(-1) end, "move left")
  map("<Right>", function() move(1) end, "move right")
  map("<Up>",    function() move(-7) end, "move up")
  map("<Down>",  function() move(7) end, "move down")
  map("<C-p>",   function() change_month(-1) end, "previous month")
  map("<C-n>",   function() change_month(1) end, "next month")
  map("t",       function() goto_today() end, "jump to today")
  map("<CR>",    function() select_day() end, "open or create daily note")
  map("q",       function() close() end, "close")
  map("<Esc>",   function() close() end, "close")
end

function M.open()
  local t = today()
  state.y, state.m, state.d = t.y, t.m, t.d

  if buf and vim.api.nvim_buf_is_valid(buf)
    and win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_current_win(win)
    render()
    return
  end

  buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype",  "nofile", { buf = buf })
  vim.api.nvim_set_option_value("swapfile", false,    { buf = buf })
  setup_keymaps(buf)

  grid       = utils.month_grid(state.y, state.m, start_weekday())
  local width  = grid.width + 2
  local height = #grid.lines + 2
  local row    = math.floor((vim.o.lines - height) / 2)
  local col    = math.floor((vim.o.columns - width) / 2)

  win = vim.api.nvim_open_win(buf, true, {
    relative  = "editor",
    width     = width,
    height    = height,
    row       = row,
    col       = col,
    style     = "minimal",
    border    = "rounded",
    title     = " " .. selected_date_text() .. " ",
    title_pos = "center",
    footer    = "  h/j/k/l move · C-p/C-n month · t today · Enter open · q close  ",
    footer_pos = "center",
  })

  vim.api.nvim_create_autocmd("WinClosed", {
    pattern  = tostring(win),
    once     = true,
    callback = function()
      if buf and vim.api.nvim_buf_is_valid(buf) then
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end
      buf, win = nil, nil
    end,
  })

  render()
end

return M
