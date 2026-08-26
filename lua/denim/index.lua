local M = {}

local utils = require("denim.utils")

local function get_opts()
  return require("denim.config").options
end

local function gather_notes(notes_dir)
  local all = vim.fn.systemlist({
    "find", notes_dir, "-maxdepth", "1", "-name", "*.md",
  })

  local notes = {}
  for _, filepath in ipairs(all) do
    local filename = vim.fn.fnamemodify(filepath, ":t")
    local date_raw = filename:match("^(%d%d%d%d%d%d%d%d)")
    if date_raw then
      local workflow = get_opts().workflow
      local tags = utils.tags_from_filename(filename)
      local tag_set = {}
      for _, t in ipairs(tags) do tag_set[t] = true end
      local status = "note"
      if tag_set[workflow.todo] then
        status = "open_todo"
      elseif tag_set[workflow.done] then
        status = "done_todo"
      end

      local date_fmt = date_raw:sub(1, 4) .. "-" .. date_raw:sub(5, 6) .. "-" .. date_raw:sub(7, 8)

      local slug  = filename:match("%-%-(.-)__") or filename:match("%-%-(.-)%.md$")
      local title = slug and slug:gsub("-", " ") or vim.fn.fnamemodify(filepath, ":t:r")
      if title == "" then title = date_fmt end

      table.insert(notes, {
        filepath = filepath,
        date     = date_raw,
        date_fmt = date_fmt,
        title    = title,
        status   = status,
        rel_path = filename,
      })
    end
  end

  table.sort(notes, function(a, b)
    if a.date == b.date then return a.filepath > b.filepath end
    return a.date > b.date
  end)

  return notes
end

local function build_lines(notes)
  if #notes == 0 then
    return { "# Notes Index", "", "No notes yet." }
  end

  local lines        = { "# Notes Index", "" }
  local current_date = nil

  for _, note in ipairs(notes) do
    if note.date_fmt ~= current_date then
      if current_date then table.insert(lines, "") end
      table.insert(lines, "## " .. note.date_fmt)
      table.insert(lines, "")
      current_date = note.date_fmt
    end

    local item
    if note.status == "open_todo" then
      item = "- [ ] [" .. note.title .. "](" .. note.rel_path .. ")"
    elseif note.status == "done_todo" then
      item = "- [x] [" .. note.title .. "](" .. note.rel_path .. ")"
    else
      item = "- [" .. note.title .. "](" .. note.rel_path .. ")"
    end

    table.insert(lines, item)
  end

  return lines
end

M._build_lines = build_lines

function M.open()
  local opts    = get_opts()
  local bufname = opts.notes_dir .. "/.index"
  local notes   = gather_notes(opts.notes_dir)
  local lines   = build_lines(notes)

  local bufnr = vim.fn.bufnr(bufname)
  if bufnr == -1 then
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, bufname)

    vim.keymap.set("n", "<CR>", function()
      require("denim.notes").follow_link()
    end, { buffer = bufnr, desc = "denim: follow link" })

    vim.keymap.set("n", "r", function()
      M.open()
    end, { buffer = bufnr, desc = "denim: refresh index" })

    vim.keymap.set("n", "q", "<cmd>bdelete<cr>", {
      buffer = bufnr, desc = "denim: close index",
    })
  end

  vim.api.nvim_set_option_value("buftype",  "nofile", { buf = bufnr })
  vim.api.nvim_set_option_value("swapfile", false,    { buf = bufnr })
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
end

return M
