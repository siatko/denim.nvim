local M = {}

local function get_opts()
  return require("denim.config").options
end

local utils = require("denim.utils")

local function get_telescope()
  local ok, t = pcall(require, "telescope.builtin")
  if not ok then
    vim.notify("denim: telescope.nvim is required for search", vim.log.levels.ERROR)
    return nil
  end
  return t
end

local function find_cmd()
  if vim.fn.executable("fd") == 1 then
    return { "fd", "--type", "f", "--extension", "md", "--exclude", ".templates" }
  end
  return { "find", ".", "-name", "*.md", "-not", "-path", "*/.templates/*" }
end

local function multiterm_sorter()
  return require("telescope.sorters").new({
    scoring_function = function(_, prompt, line)
      return utils.multiterm_match(prompt, line) and 1 or -1
    end,
  })
end

function M.search_notes()
  local t = get_telescope()
  if not t then return end

  t.find_files({
    prompt_title = "Notes",
    cwd = get_opts().notes_dir,
    find_command = find_cmd(),
    sorter = multiterm_sorter(),
  })
end

function M.search_content()
  local t = get_telescope()
  if not t then return end

  t.live_grep({
    prompt_title = "Notes Content",
    cwd = get_opts().notes_dir,
    additional_args = { "--glob", "*.md", "--glob", "!.templates/**" },
    on_input_filter_cb = function(prompt)
      local terms = vim.split(prompt, "%s+", { trimempty = true })
      return { prompt = terms[1] or "" }
    end,
    sorter = multiterm_sorter(),
  })
end


local function all_note_files(notes_dir)
  if vim.fn.executable("fd") == 1 then
    return vim.fn.systemlist({ "fd", "--type", "f", "--extension", "md", "--max-depth", "1", ".", notes_dir })
  end
  return vim.fn.systemlist({ "find", notes_dir, "-maxdepth", "1", "-name", "*.md" })
end

local tags_from_filename = utils.tags_from_filename

local function collect_tags(notes_dir)
  local seen, tags = {}, {}
  for _, filepath in ipairs(all_note_files(notes_dir)) do
    for _, tag in ipairs(tags_from_filename(vim.fn.fnamemodify(filepath, ":t"))) do
      if not seen[tag] then
        seen[tag] = true
        table.insert(tags, tag)
      end
    end
  end
  table.sort(tags)
  return tags
end

local function files_with_all_tags(notes_dir, selected_tags)
  local result = {}
  for _, filepath in ipairs(all_note_files(notes_dir)) do
    local tag_set = {}
    for _, t in ipairs(tags_from_filename(vim.fn.fnamemodify(filepath, ":t"))) do
      tag_set[t] = true
    end
    local has_all = true
    for _, tag in ipairs(selected_tags) do
      if not tag_set[tag] then has_all = false; break end
    end
    if has_all then table.insert(result, filepath) end
  end
  return result
end

local function open_tag_results(notes_dir, selected)
  local files = files_with_all_tags(notes_dir, selected)
  if #files == 0 then
    vim.notify("denim: no notes found for tags: " .. table.concat(selected, " "), vim.log.levels.INFO)
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf    = require("telescope.config").values

  pickers.new({}, {
    prompt_title = "Tags: " .. table.concat(selected, " "),
    finder = finders.new_table({
      results = files,
      entry_maker = function(entry)
        return {
          value   = entry,
          display = vim.fn.fnamemodify(entry, ":~:."),
          ordinal = entry,
          path    = entry,
        }
      end,
    }),
    sorter    = conf.generic_sorter({}),
    previewer = conf.file_previewer({}),
  }):find()
end

local relative_path = utils.relative_path
local slugify_tag   = utils.slugify_tag

function M.insert_link()
  local notes_dir    = get_opts().notes_dir
  local current_file = vim.fn.expand("%:p")

  if current_file == "" then
    vim.notify("denim: save the file before inserting a link", vim.log.levels.WARN)
    return
  end

  local entries = {}
  for _, filepath in ipairs(all_note_files(notes_dir)) do
    if filepath ~= current_file then
      local lines = vim.fn.readfile(filepath, "", 1)
      local title = (lines and lines[1] and lines[1]:match("^#%s+(.+)$"))
        or vim.fn.fnamemodify(filepath, ":t:r")
      table.insert(entries, { path = filepath, title = title })
    end
  end

  local pickers      = require("telescope.pickers")
  local finders      = require("telescope.finders")
  local conf         = require("telescope.config").values
  local actions      = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local from_dir     = vim.fn.fnamemodify(current_file, ":h")

  pickers.new({}, {
    prompt_title = "Link to note",
    finder = finders.new_table({
      results = entries,
      entry_maker = function(e)
        return {
          value   = e,
          display = e.title .. "  (" .. vim.fn.fnamemodify(e.path, ":t") .. ")",
          ordinal = e.title .. " " .. vim.fn.fnamemodify(e.path, ":t"),
          path    = e.path,
        }
      end,
    }),
    sorter    = conf.generic_sorter({}),
    previewer = conf.file_previewer({}),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        if not entry then return end
        actions.close(prompt_bufnr)
        vim.schedule(function()
          local rel  = relative_path(from_dir, entry.value.path)
          local link = string.format("[%s](%s)", utils.link_text(entry.value.title), rel)
          local row, col = unpack(vim.api.nvim_win_get_cursor(0))
          local ln = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
          vim.api.nvim_buf_set_lines(0, row - 1, row, false,
            { ln:sub(1, col + 1) .. link .. ln:sub(col + 2) })
          vim.api.nvim_win_set_cursor(0, { row, col + #link })
        end)
      end)
      return true
    end,
  }):find()
end

function M.update_links_to(old_filepath, new_filepath, opts)
  opts = opts or {}
  local old_abs = vim.fn.fnamemodify(old_filepath, ":p")
  local new_abs = vim.fn.fnamemodify(new_filepath, ":p")
  local updated = 0

  for _, filepath in ipairs(all_note_files(get_opts().notes_dir)) do
    local abs      = vim.fn.fnamemodify(filepath, ":p")
    if abs ~= old_abs and abs ~= new_abs then
      local lines    = vim.fn.readfile(filepath)
      local file_dir = vim.fn.fnamemodify(filepath, ":h")
      local changed  = false

      local new_lines = vim.tbl_map(function(line)
        return line:gsub("%[(.-)%]%((.-)%)", function(text, path)
          local resolved = vim.fn.fnamemodify(file_dir .. "/" .. path, ":p")
          if resolved == old_abs then
            changed = true
            return "[" .. text .. "](" .. relative_path(file_dir, new_filepath) .. ")"
          end
        end)
      end, lines)

      if changed then
        vim.fn.writefile(new_lines, filepath)
        updated = updated + 1
        local bufnr = vim.fn.bufnr(filepath)
        if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
          vim.api.nvim_buf_call(bufnr, function() vim.cmd("edit") end)
        end
      end
    end
  end

  if updated > 0 and not opts.silent then
    vim.notify(
      string.format("denim: updated links in %d note%s", updated, updated == 1 and "" or "s"),
      vim.log.levels.INFO
    )
  end
  return updated
end

function M.backlinks()
  local current_file = vim.fn.expand("%:p")
  if current_file == "" then
    vim.notify("denim: save the file first", vim.log.levels.WARN)
    return
  end

  local filename  = vim.fn.fnamemodify(current_file, ":t")
  local notes_dir = get_opts().notes_dir
  local results   = {}

  for _, filepath in ipairs(all_note_files(notes_dir)) do
    if filepath ~= current_file then
      for _, line in ipairs(vim.fn.readfile(filepath)) do
        local stripped = line:gsub("!%[[^%]]*%]%([^%)]*%)", "")
        if stripped:find("](" .. filename, 1, true) then
          table.insert(results, filepath)
          break
        end
      end
    end
  end

  if #results == 0 then
    vim.notify("denim: no backlinks to " .. filename, vim.log.levels.INFO)
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf    = require("telescope.config").values

  pickers.new({}, {
    prompt_title = "Backlinks → " .. filename,
    finder = finders.new_table({
      results = results,
      entry_maker = function(entry)
        local lines = vim.fn.readfile(entry, "", 1)
        local title = (lines and lines[1] and lines[1]:match("^#%s+(.+)$"))
          or vim.fn.fnamemodify(entry, ":t:r")
        return {
          value   = entry,
          display = title .. "  (" .. vim.fn.fnamemodify(entry, ":t") .. ")",
          ordinal = title,
          path    = entry,
        }
      end,
    }),
    sorter    = conf.generic_sorter({}),
    previewer = conf.file_previewer({}),
  }):find()
end

function M.pick_tags(callback, opts)
  opts = opts or {}
  local pre_selected = opts.pre_selected or {}
  local extra_tags   = opts.extra_tags or {}
  local all_tags     = collect_tags(get_opts().notes_dir)

  -- Merge tags created this session (not yet on disk) into the list
  local tag_set = {}
  for _, t in ipairs(all_tags) do tag_set[t] = true end
  for _, t in ipairs(extra_tags) do
    if not tag_set[t] then
      table.insert(all_tags, t)
      tag_set[t] = true
    end
  end
  table.sort(all_tags)

  local pickers      = require("telescope.pickers")
  local finders      = require("telescope.finders")
  local conf         = require("telescope.config").values
  local actions      = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  pickers.new({}, {
    prompt_title = opts.title or "Tags  (<Tab> select · type new+<Enter> to add · empty <Enter> done)",
    finder = finders.new_table({ results = all_tags }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      if #pre_selected > 0 then
        vim.defer_fn(function()
          if not vim.api.nvim_buf_is_valid(prompt_bufnr) then return end
          local picker = action_state.get_current_picker(prompt_bufnr)
          if not picker or not picker.manager then return end
          local pre_set = {}
          for _, t in ipairs(pre_selected) do pre_set[t] = true end
          pcall(function()
            local num      = picker.manager:num_results()
            local current  = picker:get_selection_row()
            local reset    = picker:get_reset_row()
            local dir      = (picker.sorting_strategy == "ascending") and 1 or -1
            for step = 0, num - 1 do
              local row   = reset + dir * step
              local entry = picker.manager:get_entry(picker:get_index(row))
              if entry and pre_set[entry.value] then
                picker:move_selection(row - current)
                current = row
                actions.toggle_selection(prompt_bufnr)
              end
            end
          end)
        end, 50)
      end

      actions.select_default:replace(function()
        local picker      = action_state.get_current_picker(prompt_bufnr)
        local multi       = picker:get_multi_selection()
        local prompt_text = vim.trim(action_state.get_current_line())
        local selected    = {}

        for _, e in ipairs(multi) do
          table.insert(selected, e.value)
        end

        if prompt_text == "" then
          actions.close(prompt_bufnr)
          vim.schedule(function() callback(selected) end)
          return
        end

        -- Parse space-separated new tags, then re-open with everything pre-selected
        local new_extra = vim.deepcopy(extra_tags)
        for word in prompt_text:gmatch("%S+") do
          local tag = slugify_tag(word)
          if tag ~= "" then
            local found = false
            for _, s in ipairs(selected) do
              if s == tag then found = true; break end
            end
            if not found then table.insert(selected, tag) end
            if not tag_set[tag] then
              table.insert(new_extra, tag)
              tag_set[tag] = true
            end
          end
        end

        actions.close(prompt_bufnr)
        vim.schedule(function()
          M.pick_tags(callback, {
            pre_selected = selected,
            extra_tags   = new_extra,
            title        = opts.title,
          })
        end)
      end)
      map("n", "<Esc>", function() actions.close(prompt_bufnr) end)
      map("i", "<Esc>", function() actions.close(prompt_bufnr) end)
      return true
    end,
  }):find()
end

local function template_files(notes_dir)
  return vim.fn.glob(notes_dir .. "/.templates/*.md", false, true)
end

function M.pick_template(callback)
  local notes_dir = get_opts().notes_dir
  local tmpls     = template_files(notes_dir)

  if #tmpls == 0 then
    vim.notify(
      "denim: no templates found; add .md files to " .. notes_dir .. "/.templates",
      vim.log.levels.INFO
    )
    return
  end

  local pickers      = require("telescope.pickers")
  local finders      = require("telescope.finders")
  local conf         = require("telescope.config").values
  local actions      = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local entries = vim.tbl_map(function(path)
    return { path = path, name = vim.fn.fnamemodify(path, ":t:r") }
  end, tmpls)

  pickers.new({}, {
    prompt_title = "Choose template",
    finder = finders.new_table({
      results = entries,
      entry_maker = function(e)
        return { value = e, display = e.name, ordinal = e.name, path = e.path }
      end,
    }),
    sorter    = conf.generic_sorter({}),
    previewer = conf.file_previewer({}),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        if not entry then return end
        actions.close(prompt_bufnr)
        vim.schedule(function() callback(entry.value.path) end)
      end)
      return true
    end,
  }):find()
end

function M.search_templates()
  local notes_dir = get_opts().notes_dir
  local tmpls     = template_files(notes_dir)
  local tmpl_dir  = notes_dir .. "/.templates"

  if #tmpls == 0 then
    vim.notify(
      "denim: no templates found; add .md files to " .. tmpl_dir,
      vim.log.levels.INFO
    )
    return
  end

  local t = get_telescope()
  if not t then return end

  local cmd = vim.fn.executable("fd") == 1
    and { "fd", "--type", "f", "--extension", "md", "--max-depth", "1" }
    or  { "find", ".", "-maxdepth", "1", "-name", "*.md" }

  t.find_files({
    prompt_title = "Templates",
    cwd          = tmpl_dir,
    find_command = cmd,
  })
end


function M.rename_tag()
  local notes_dir = get_opts().notes_dir
  local all_tags  = collect_tags(notes_dir)

  if #all_tags == 0 then
    vim.notify("denim: no tags found", vim.log.levels.INFO)
    return
  end

  local pickers      = require("telescope.pickers")
  local finders      = require("telescope.finders")
  local conf         = require("telescope.config").values
  local actions      = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  pickers.new({}, {
    prompt_title = "Rename tag",
    finder = finders.new_table({ results = all_tags }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        if not entry then return end
        local old_tag = entry.value
        actions.close(prompt_bufnr)
        vim.schedule(function()
          vim.ui.input({ prompt = "Rename '" .. old_tag .. "' to: ", default = old_tag }, function(input)
            if not input then return end
            local new_tag = slugify_tag(vim.trim(input))
            if new_tag == old_tag then
              vim.notify("denim: tag unchanged", vim.log.levels.INFO)
              return
            end
            if new_tag == "" then
              vim.notify("denim: invalid tag name", vim.log.levels.WARN)
              return
            end

            local cur_file      = vim.fn.expand("%:p")
            local cur_buf       = vim.api.nvim_get_current_buf()
            local files_renamed = 0
            local links_updated = 0

            for _, filepath in ipairs(all_note_files(notes_dir)) do
              local filename     = vim.fn.fnamemodify(filepath, ":t")
              local new_filename, changed = utils.rename_tag_in_filename(filename, old_tag, new_tag)
              if changed then
                local new_filepath = vim.fn.fnamemodify(filepath, ":h") .. "/" .. new_filename
                vim.fn.rename(filepath, new_filepath)
                files_renamed = files_renamed + 1
                links_updated = links_updated + M.update_links_to(filepath, new_filepath, { silent = true })
                if vim.fn.fnamemodify(filepath, ":p") == cur_file then
                  vim.cmd("edit " .. vim.fn.fnameescape(new_filepath))
                  vim.api.nvim_buf_delete(cur_buf, { force = true })
                end
              end
            end

            if files_renamed == 0 then
              vim.notify("denim: no files with tag '" .. old_tag .. "'", vim.log.levels.INFO)
            else
              vim.notify(string.format(
                "denim: '%s' → '%s': %d file%s renamed, %d link%s updated",
                old_tag, new_tag,
                files_renamed, files_renamed == 1 and "" or "s",
                links_updated, links_updated == 1 and "" or "s"
              ), vim.log.levels.INFO)
            end
          end)
        end)
      end)
      return true
    end,
  }):find()
end

function M.delete_notes()
  local notes_dir = get_opts().notes_dir
  local files = all_note_files(notes_dir)

  if #files == 0 then
    vim.notify("denim: no notes found", vim.log.levels.INFO)
    return
  end

  local pickers      = require("telescope.pickers")
  local finders      = require("telescope.finders")
  local conf         = require("telescope.config").values
  local actions      = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  pickers.new({}, {
    prompt_title = "Delete Notes  (<Tab> multi-select, <Enter> confirm)",
    finder = finders.new_table({
      results = files,
      entry_maker = function(entry)
        return {
          value   = entry,
          display = vim.fn.fnamemodify(entry, ":~:."),
          ordinal = entry,
          path    = entry,
        }
      end,
    }),
    sorter    = conf.generic_sorter({}),
    previewer = conf.file_previewer({}),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local picker = action_state.get_current_picker(prompt_bufnr)
        local multi  = picker:get_multi_selection()
        local to_delete
        if #multi > 0 then
          to_delete = vim.tbl_map(function(e) return e.value end, multi)
        else
          local entry = action_state.get_selected_entry()
          if not entry then return end
          to_delete = { entry.value }
        end
        actions.close(prompt_bufnr)
        vim.schedule(function()
          local names = vim.tbl_map(function(p) return vim.fn.fnamemodify(p, ":t") end, to_delete)
          local msg = #to_delete == 1
            and ("Delete 1 note: " .. names[1])
            or  ("Delete " .. #to_delete .. " notes: " .. table.concat(names, ", "))
          vim.ui.select({ "Yes", "No" }, { prompt = msg .. "?" }, function(choice)
            if choice ~= "Yes" then return end
            local deleted = 0
            for _, filepath in ipairs(to_delete) do
              local bufnr = vim.fn.bufnr(filepath)
              if bufnr ~= -1 then
                vim.api.nvim_buf_delete(bufnr, { force = true })
              end
              if vim.fn.delete(filepath) == 0 then
                deleted = deleted + 1
              else
                vim.notify("denim: failed to delete " .. vim.fn.fnamemodify(filepath, ":t"), vim.log.levels.ERROR)
              end
            end
            vim.notify(
              string.format("denim: deleted %d note%s", deleted, deleted == 1 and "" or "s"),
              vim.log.levels.INFO
            )
          end)
        end)
      end)
      return true
    end,
  }):find()
end

function M.search_untagged()
  local notes_dir = get_opts().notes_dir
  local files = {}
  for _, filepath in ipairs(all_note_files(notes_dir)) do
    if #tags_from_filename(vim.fn.fnamemodify(filepath, ":t")) == 0 then
      table.insert(files, filepath)
    end
  end

  if #files == 0 then
    vim.notify("denim: no untagged notes found", vim.log.levels.INFO)
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf    = require("telescope.config").values

  pickers.new({}, {
    prompt_title = "Untagged Notes",
    finder = finders.new_table({
      results = files,
      entry_maker = function(entry)
        return {
          value   = entry,
          display = vim.fn.fnamemodify(entry, ":~:."),
          ordinal = entry,
          path    = entry,
        }
      end,
    }),
    sorter    = conf.generic_sorter({}),
    previewer = conf.file_previewer({}),
  }):find()
end

function M.search_tags()
  local notes_dir = get_opts().notes_dir
  local all_tags = collect_tags(notes_dir)

  if #all_tags == 0 then
    vim.notify("denim: no tags found in notes", vim.log.levels.INFO)
    return
  end

  local pickers      = require("telescope.pickers")
  local finders      = require("telescope.finders")
  local conf         = require("telescope.config").values
  local actions      = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  pickers.new({}, {
    prompt_title = "Tags  (<Tab> multi-select, <Enter> search)",
    finder = finders.new_table({ results = all_tags }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local picker = action_state.get_current_picker(prompt_bufnr)
        local multi  = picker:get_multi_selection()
        local selected
        if #multi > 0 then
          selected = vim.tbl_map(function(e) return e.value end, multi)
        else
          local entry = action_state.get_selected_entry()
          if not entry then return end
          selected = { entry.value }
        end
        actions.close(prompt_bufnr)
        vim.schedule(function() open_tag_results(notes_dir, selected) end)
      end)
      return true
    end,
  }):find()
end

return M
