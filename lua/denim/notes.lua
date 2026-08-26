local M = {}

local function get_opts()
  return require("denim.config").options
end

local utils = require("denim.utils")
local slugify_title      = utils.slugify_title
local slugify_tag        = utils.slugify_tag
local tags_from_filename = utils.tags_from_filename
local resolve_slug       = utils.resolve_slug

function M.new_note()
  local opts = get_opts()
  vim.fn.mkdir(opts.notes_dir, "p")

  vim.ui.input({ prompt = "Note name: " }, function(name)
    if not name or name == "" then return end
    vim.schedule(function()
      require("denim.telescope").pick_tags(function(tags)
        local date = os.date("%Y%m%dT%H%M%S")
        local slug = slugify_title(name)
        local slugged = vim.tbl_map(slugify_tag, tags)
        table.sort(slugged)
        local tag_suffix = #slugged > 0 and ("__" .. table.concat(slugged, "_")) or ""
        local filename = date .. "--" .. slug .. tag_suffix .. ".md"
        local filepath = opts.notes_dir .. "/" .. filename

        if vim.fn.filereadable(filepath) == 1 then
          vim.notify("denim: note already exists, opening: " .. filename, vim.log.levels.INFO)
          vim.cmd("edit " .. vim.fn.fnameescape(filepath))
          return
        end

        vim.fn.writefile({}, filepath)
        vim.cmd("edit " .. vim.fn.fnameescape(filepath))
        vim.schedule(function()
          vim.api.nvim_win_set_cursor(0, { 1, 0 })
          vim.cmd("startinsert")
        end)
      end)
    end)
  end)
end

-- date is an optional "YYYYMMDD" string; defaults to today
function M.daily_note(date)
  local opts = get_opts()
  vim.fn.mkdir(opts.notes_dir, "p")

  local daily_tag = slugify_tag(opts.workflow.daily)
  local date_raw  = (date or os.date("%Y%m%d")):gsub("%D", "")
  local filename  = date_raw .. "T000000--__" .. daily_tag .. ".md"
  local filepath  = opts.notes_dir .. "/" .. filename

  if vim.fn.filereadable(filepath) == 1 then
    vim.notify("denim: daily note already exists, opening: " .. filename, vim.log.levels.INFO)
    vim.cmd("edit " .. vim.fn.fnameescape(filepath))
    return
  end

  vim.fn.writefile({}, filepath)
  vim.cmd("edit " .. vim.fn.fnameescape(filepath))
end

local function find_and_remove_stop(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for i, line in ipairs(lines) do
    local col = line:find("%$")
    if col then
      vim.api.nvim_buf_set_lines(bufnr, i - 1, i, false, { line:sub(1, col - 1) .. line:sub(col + 1) })
      vim.api.nvim_win_set_cursor(0, { i, col - 1 })
      return true
    end
  end
  return false
end

local function activate_tab_stops(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local has_stop = false
  local stop_at_eol = false
  for _, line in ipairs(lines) do
    local col = line:find("%$")
    if col then
      has_stop = true
      -- col is 1-indexed; after removal the line is 1 char shorter
      -- if the 0-indexed target column >= remaining length, $ was at EOL
      stop_at_eol = (col - 1) >= (#line - 1)
      break
    end
  end

  if not has_stop then
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.cmd("startinsert")
    return
  end

  find_and_remove_stop(bufnr)
  -- startinsert! (append) when $ was at EOL: normal-mode cursor gets clamped
  -- one position short, so we need append to land after the last character
  vim.cmd(stop_at_eol and "startinsert!" or "startinsert")
  vim.keymap.set("i", "<Tab>", function()
    if not find_and_remove_stop(bufnr) then
      vim.keymap.del("i", "<Tab>", { buffer = bufnr })
    end
  end, { buffer = bufnr })
end

local function open_path(path)
  if path:match("^https?://") or path:match("^ftp://") then
    vim.fn.jobstart({ "xdg-open", path }, { detach = true })
    return
  end
  local current_dir = vim.fn.fnamemodify(vim.fn.expand("%:p"), ":h")
  local target = vim.fn.fnamemodify(current_dir .. "/" .. path, ":p")
  local ext = target:match("%.(%w+)$")
  local image_exts = { png=true, jpg=true, jpeg=true, gif=true, webp=true, svg=true, bmp=true, tiff=true, tif=true }
  if ext and image_exts[ext:lower()] then
    vim.notify("denim: image — " .. vim.fn.fnamemodify(target, ":t"), vim.log.levels.INFO)
  elseif vim.fn.filereadable(target) == 1 then
    vim.cmd("edit " .. vim.fn.fnameescape(target))
  else
    vim.notify("denim: file not found: " .. target, vim.log.levels.WARN)
  end
end

function M.new_template()
  local opts = get_opts()
  local tmpl_dir = opts.notes_dir .. "/.templates"
  vim.fn.mkdir(tmpl_dir, "p")
  vim.ui.input({ prompt = "Template name: " }, function(name)
    if not name or name == "" then return end
    local filename = slugify_title(name) .. ".md"
    local filepath = tmpl_dir .. "/" .. filename
    vim.schedule(function()
      vim.cmd("edit " .. vim.fn.fnameescape(filepath))
    end)
  end)
end

function M.new_note_from_template()
  local opts = get_opts()
  vim.fn.mkdir(opts.notes_dir, "p")

  require("denim.telescope").pick_template(function(tmpl_path)
    vim.ui.input({ prompt = "Note name: " }, function(name)
      if not name or name == "" then return end
      vim.schedule(function()
        require("denim.telescope").pick_tags(function(tags)
          local date    = os.date("%Y%m%dT%H%M%S")
          local slug    = slugify_title(name)
          local slugged = vim.tbl_map(slugify_tag, tags)
          table.sort(slugged)
          local tag_suffix = #slugged > 0 and ("__" .. table.concat(slugged, "_")) or ""
          local filename   = date .. "--" .. slug .. tag_suffix .. ".md"
          local filepath   = opts.notes_dir .. "/" .. filename

          if vim.fn.filereadable(filepath) == 1 then
            vim.notify("denim: note already exists, opening: " .. filename, vim.log.levels.INFO)
            vim.cmd("edit " .. vim.fn.fnameescape(filepath))
            return
          end

          local tmpl_lines = vim.fn.readfile(tmpl_path)
          vim.fn.writefile(tmpl_lines, filepath)
          vim.cmd("edit " .. vim.fn.fnameescape(filepath))
          vim.schedule(function()
            activate_tab_stops(vim.api.nvim_get_current_buf())
          end)
        end)
      end)
    end)
  end)
end


function M.follow_link()
  local opts     = get_opts()
  local filepath = vim.fn.resolve(vim.fn.expand("%:p"))
  if not vim.startswith(filepath, opts.notes_dir) then return end
  local line = vim.api.nvim_get_current_line()
  local col  = vim.api.nvim_win_get_cursor(0)[2] + 1
  local path = utils.find_link_path(line, col)
  if path then open_path(path) end
end

function M.cycle_workflow()
  local opts     = get_opts()
  local filepath = vim.fn.expand("%:p")

  if not vim.startswith(filepath, opts.notes_dir) then
    vim.notify("denim: current file is not in notes directory", vim.log.levels.WARN)
    return
  end

  local filename = vim.fn.fnamemodify(filepath, ":t")
  local todo_tag = opts.workflow.todo
  local done_tag = opts.workflow.done
  local tags     = tags_from_filename(filename)

  local new_filename, ok, label
  if vim.tbl_contains(tags, done_tag) then
    new_filename, ok = utils.remove_tag_from_filename(filename, done_tag)
    label = "note"
  elseif vim.tbl_contains(tags, todo_tag) then
    new_filename, ok = utils.rename_tag_in_filename(filename, todo_tag, done_tag)
    label = done_tag
  else
    new_filename, ok = utils.add_tag_to_filename(filename, todo_tag)
    label = todo_tag
  end
  if not ok then return end

  local new_filepath = vim.fn.fnamemodify(filepath, ":h") .. "/" .. new_filename
  local old_buf = vim.api.nvim_get_current_buf()
  vim.fn.rename(filepath, new_filepath)
  require("denim.telescope").update_links_to(filepath, new_filepath)
  vim.cmd("edit " .. vim.fn.fnameescape(new_filepath))
  vim.api.nvim_buf_delete(old_buf, { force = true })
  vim.notify("denim: " .. label .. " — " .. new_filename, vim.log.levels.INFO)
end

function M.refactor()
  local opts     = get_opts()
  local filepath = vim.fn.expand("%:p")
  if filepath == "" then
    vim.notify("denim: no file open", vim.log.levels.WARN)
    return
  end

  if not vim.startswith(filepath, opts.notes_dir) then
    vim.notify("denim: current file is not in notes directory", vim.log.levels.WARN)
    return
  end

  local filename     = vim.fn.fnamemodify(filepath, ":t")
  local current_tags = tags_from_filename(filename)
  local base         = filename:match("^(.-)__[^%.]+%.md$") or filename:match("^(.-)%.md$")

  local date_and_marker = base:match("^(%d+T?%d*%-%-)")
  local current_slug    = date_and_marker and base:sub(#date_and_marker + 1) or base

  vim.ui.input({ prompt = "Note name: ", default = current_slug }, function(name)
    if name == nil then return end

    local new_slug = resolve_slug(name, current_slug, current_slug)

    vim.schedule(function()
      require("denim.telescope").pick_tags(function(tags)
        local slugged    = vim.tbl_map(slugify_tag, tags)
        table.sort(slugged)
        local tag_suffix = #slugged > 0 and ("__" .. table.concat(slugged, "_")) or ""
        local new_filename = (date_and_marker or "") .. new_slug .. tag_suffix .. ".md"
        local new_filepath = vim.fn.fnamemodify(filepath, ":h") .. "/" .. new_filename

        if new_filepath == filepath then
          vim.notify("denim: nothing changed", vim.log.levels.INFO)
          return
        end

        local old_buf = vim.api.nvim_get_current_buf()
        vim.fn.rename(filepath, new_filepath)
        require("denim.telescope").update_links_to(filepath, new_filepath)
        vim.cmd("edit " .. vim.fn.fnameescape(new_filepath))
        vim.api.nvim_buf_delete(old_buf, { force = true })
        vim.notify("denim: → " .. new_filename, vim.log.levels.INFO)
      end, { pre_selected = current_tags })
    end)
  end)
end

local image_exts = {
  png = true, jpg = true, jpeg = true, gif = true, webp = true,
  svg = true, bmp = true, tiff = true, tif = true, ico = true, avif = true,
}

-- Returns path, true on success; nil, true if it's a file URI but invalid; nil, false if not a file URI
local function parse_file_uri(clip)
  local stripped = clip:gsub("%s+$", "")
  if not stripped:match("^file://") then return nil, false end
  if stripped:match("[\r\n]") then return nil, true end
  local path = stripped:gsub("^file://", ""):gsub("%%(%x%x)", function(h)
    return string.char(tonumber(h, 16))
  end)
  return path, true
end

local function paste_name_tags_then(prompt, cb)
  vim.ui.input({ prompt = prompt }, function(name)
    if not name or name == "" then return end
    vim.schedule(function()
      require("denim.telescope").pick_tags(function(tags)
        cb(name, tags)
      end)
    end)
  end)
end

local function insert_link_at_cursor(link)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local ln = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
  vim.api.nvim_buf_set_lines(0, row - 1, row, false,
    { ln:sub(1, col + 1) .. link .. ln:sub(col + 2) })
  vim.api.nvim_win_set_cursor(0, { row, col + #link })
end

function M.paste_image()
  local opts = get_opts()
  vim.fn.mkdir(opts.notes_dir, "p")

  local src, is_file_uri = parse_file_uri(vim.fn.getreg("+"))
  if is_file_uri and not src then
    vim.notify("denim: only a single file can be pasted at a time", vim.log.levels.WARN)
    return
  end
  if src then
    if vim.fn.isdirectory(src) == 1 then
      vim.notify("denim: pasting folders is not supported", vim.log.levels.WARN)
      return
    end
    if vim.fn.filereadable(src) == 0 then
      vim.notify("denim: file not readable: " .. src, vim.log.levels.ERROR)
      return
    end
    local ext = src:match("%.([^.]+)$") or ""
    local is_image = image_exts[ext:lower()]

    paste_name_tags_then("File name: ", function(name, tags)
      local date = os.date("%Y%m%dT%H%M%S")
      local slugged = vim.tbl_map(slugify_tag, tags)
      table.sort(slugged)
      local tag_suffix = #slugged > 0 and ("__" .. table.concat(slugged, "_")) or ""
      local file_name = date .. "--" .. slugify_title(name) .. tag_suffix .. "." .. ext
      local dest = opts.notes_dir .. "/" .. file_name
      if vim.fn.filereadable(dest) == 1 then
        vim.notify("denim: file already exists: " .. file_name, vim.log.levels.WARN)
        return
      end
      local ok, err = vim.uv.fs_copyfile(src, dest)
      if not ok then
        vim.notify("denim: failed to copy file: " .. (err or ""), vim.log.levels.ERROR)
        return
      end
      local link = is_image
        and string.format("![%s](%s)", name, file_name)
        or  string.format("[%s](%s)", name, file_name)
      insert_link_at_cursor(link)
    end)
    return
  end

  -- No file URI in clipboard - fall through to img-clip for raw image data
  local ok, img_clip = pcall(require, "img-clip")
  if not ok then
    vim.notify("denim: img-clip.nvim is required for image pasting", vim.log.levels.ERROR)
    return
  end

  paste_name_tags_then("Image name: ", function(name, tags)
    local date = os.date("%Y%m%dT%H%M%S")
    local slugged = vim.tbl_map(slugify_tag, tags)
    table.sort(slugged)
    local tag_suffix = #slugged > 0 and ("__" .. table.concat(slugged, "_")) or ""
    local file_name = date .. "--" .. slugify_title(name) .. tag_suffix
    local existing = vim.fn.glob(opts.notes_dir .. "/" .. file_name .. ".*")
    if existing ~= "" then
      vim.notify(
        "denim: image already exists: " .. vim.fn.fnamemodify(existing, ":t"),
        vim.log.levels.WARN
      )
      return
    end
    img_clip.paste_image({
      dir_path = opts.notes_dir,
      file_name = file_name,
      prompt_for_file_name = false,
      insert_mode_after_paste = false,
      template = "![$FILE_NAME_NO_EXT]($FILE_NAME)",
    })
  end)
end

function M.insert_url_link()
  local clip = vim.fn.getreg("+")

  vim.ui.input({ prompt = "URL: ", default = clip }, function(url)
    if not url or url == "" then return end
    vim.ui.input({ prompt = "Link title: " }, function(title)
      if title == nil then return end
      vim.schedule(function()
        local row, col = unpack(vim.api.nvim_win_get_cursor(0))
        local ln   = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
        local link = string.format("[%s](%s)", title, url)
        vim.api.nvim_buf_set_lines(0, row - 1, row, false,
          { ln:sub(1, col + 1) .. link .. ln:sub(col + 2) })
        vim.api.nvim_win_set_cursor(0, { row, col + #link })
      end)
    end)
  end)
end

function M.capture()
  local opts = get_opts()
  vim.fn.mkdir(opts.notes_dir, "p")

  vim.ui.input({ prompt = "Capture: " }, function(name)
    if not name or name == "" then return end
    vim.schedule(function()
      local date        = os.date("%Y%m%dT%H%M%S")
      local slug        = slugify_title(name)
      local capture_tag = slugify_tag(opts.workflow.capture)
      local filename    = date .. "--" .. slug .. "__" .. capture_tag .. ".md"
      local filepath    = opts.notes_dir .. "/" .. filename

      local tmpl_path  = opts.notes_dir .. "/.templates/" .. capture_tag .. ".md"
      local tmpl_lines = vim.fn.filereadable(tmpl_path) == 1 and vim.fn.readfile(tmpl_path) or {}

      local buf = vim.api.nvim_create_buf(false, true)
      vim.bo[buf].buftype  = "nofile"
      vim.bo[buf].filetype = "markdown"

      if #tmpl_lines > 0 then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, tmpl_lines)
      end

      local width  = math.floor(vim.o.columns * 0.7)
      local height = math.floor(vim.o.lines * 0.4)
      local row    = math.floor((vim.o.lines - height) / 2)
      local col    = math.floor((vim.o.columns - width) / 2)

      local win = vim.api.nvim_open_win(buf, true, {
        relative   = "editor",
        width      = width,
        height     = height,
        row        = row,
        col        = col,
        style      = "minimal",
        border     = "rounded",
        title      = " " .. filename .. " ",
        title_pos  = "center",
        footer     = "  <C-s> save  Esc/q cancel  ",
        footer_pos = "center",
      })

      local done = false

      local function close(write)
        if done then return end
        done = true
        if write then
          local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
          vim.fn.writefile(lines, filepath)
        end
        vim.api.nvim_win_close(win, true)
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
        if write then
          vim.notify("denim: captured — " .. filename, vim.log.levels.INFO)
        end
      end

      vim.keymap.set({ "i", "n" }, "<C-s>", function() close(true) end,  { buffer = buf, nowait = true })
      vim.keymap.set("n",          "q",     function() close(false) end, { buffer = buf, nowait = true })
      vim.keymap.set("n",          "<Esc>", function() close(false) end, { buffer = buf, nowait = true })

      vim.api.nvim_create_autocmd("WinClosed", {
        pattern  = tostring(win),
        once     = true,
        callback = function()
          if not done then
            done = true
            pcall(vim.api.nvim_buf_delete, buf, { force = true })
          end
        end,
      })

      if #tmpl_lines > 0 then
        vim.schedule(function() activate_tab_stops(buf) end)
      else
        vim.api.nvim_win_set_cursor(win, { 1, 0 })
        vim.cmd("startinsert")
      end
    end)
  end)
end

function M.ensure_notes_dir()
  vim.fn.mkdir(get_opts().notes_dir, "p")
end

return M
