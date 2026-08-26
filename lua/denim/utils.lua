local M = {}

local function lower_utf8(s)
  -- Lua's string.lower() is ASCII-only; map common uppercase non-ASCII chars
  s = s:gsub("Ä", "ä"):gsub("Ö", "ö"):gsub("Ü", "ü"):gsub("ẞ", "ß")
  return s:lower()
end

function M.slugify_title(name)
  local s = lower_utf8(name)
  s = s:gsub("[%s]+", "-")
  -- %c and %p only match ASCII, so UTF-8 high bytes are preserved
  s = s:gsub("[%c%p]", function(c) if c == "-" then return c end return "" end)
  s = s:gsub("%-+", "-")
  s = s:gsub("^%-", ""):gsub("%-$", "")
  return s
end

function M.link_text(title)
  -- A title can come from a heading (already spaced) or a filename slug
  -- (dash-separated); normalise to a spaced, uppercase link label.
  return string.upper(title:gsub("%-", " "))
end

function M.slugify_tag(tag)
  local s = lower_utf8(tag)
  s = s:gsub("[%s%-]+", "_")
  s = s:gsub("[%c%p]", function(c) if c == "_" then return c end return "" end)
  s = s:gsub("_+", "_")
  s = s:gsub("^_", ""):gsub("_$", "")
  return s
end

function M.tags_from_filename(filename)
  local tag_part = filename:match("__([^%.]+)%.md$")
  if not tag_part then return {} end
  local tags = {}
  for tag in tag_part:gmatch("[^_]+") do
    if tag ~= "" then table.insert(tags, tag) end
  end
  return tags
end

function M.relative_path(from_dir, to_file)
  local function split(path)
    local t = {}
    for s in path:gmatch("[^/]+") do t[#t+1] = s end
    return t
  end
  local src, dst = split(from_dir), split(to_file)
  local i = 1
  while i <= #src and i <= #dst and src[i] == dst[i] do i = i + 1 end
  local parts = {}
  for _ = i, #src do parts[#parts+1] = ".." end
  for j = i, #dst do parts[#parts+1] = dst[j] end
  return #parts > 0 and table.concat(parts, "/") or "."
end

function M.rename_tag_in_filename(filename, old_tag, new_tag)
  local base     = filename:match("^(.-)__[^%.]+%.md$")
  local tag_part = filename:match("__([^%.]+)%.md$")
  if not tag_part then return filename, false end

  local tags, seen = {}, {}
  local found = false
  for tag in tag_part:gmatch("[^_]+") do
    local t = (tag == old_tag) and new_tag or tag
    found = found or (tag == old_tag)
    if t ~= "" and not seen[t] then
      seen[t] = true
      table.insert(tags, t)
    end
  end

  if not found then return filename, false end
  table.sort(tags)
  local suffix = #tags > 0 and ("__" .. table.concat(tags, "_")) or ""
  return base .. suffix .. ".md", true
end

function M.remove_tag_from_filename(filename, tag)
  local base     = filename:match("^(.-)__[^%.]+%.md$")
  local tag_part = filename:match("__([^%.]+)%.md$")
  if not tag_part then return filename, false end

  local tags, seen = {}, {}
  local found = false
  for t in tag_part:gmatch("[^_]+") do
    if t == tag then
      found = true
    elseif t ~= "" and not seen[t] then
      seen[t] = true
      table.insert(tags, t)
    end
  end

  if not found then return filename, false end
  local suffix = #tags > 0 and ("__" .. table.concat(tags, "_")) or ""
  return base .. suffix .. ".md", true
end

function M.add_tag_to_filename(filename, tag)
  local base = filename:match("^(.-)__[^%.]+%.md$") or filename:match("^(.-)%.md$")
  if not base then return filename, false end
  local existing = M.tags_from_filename(filename)
  for _, t in ipairs(existing) do
    if t == tag then return filename, false end
  end
  table.insert(existing, tag)
  table.sort(existing)
  return base .. "__" .. table.concat(existing, "_") .. ".md", true
end

function M.resolve_slug(name, current_title, current_slug)
  if name == "" or name:lower() == current_title:lower() then
    return current_slug
  end
  return M.slugify_title(name)
end

function M.multiterm_match(prompt, line)
  if prompt == "" then return true end
  for _, term in ipairs(vim.split(prompt, "%s+", { trimempty = true })) do
    if not line:find(term, 1, true) then return false end
  end
  return true
end

function M.find_link_path(line, col)
  local nearest_path, nearest_dist = nil, math.huge
  local pos = 1
  while pos <= #line do
    local ms, me, path = line:find("%[.-%]%((.-)%)", pos)
    if not ms then break end

    if col >= ms and col <= me then
      return path
    end
    local dist = math.min(math.abs(col - ms), math.abs(col - me))
    if dist < nearest_dist then
      nearest_dist = dist
      nearest_path = path
    end
    pos = me + 1
  end
  return nearest_path
end

local function is_leap(year)
  return (year % 4 == 0 and year % 100 ~= 0) or year % 400 == 0
end

function M.days_in_month(year, month)
  if month == 2 then return is_leap(year) and 29 or 28 end
  local lengths = { 31, 0, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
  return lengths[month]
end

-- Zeller's congruence; returns 1 = Monday .. 7 = Sunday
function M.day_of_week(year, month, day)
  local m, y = month, year
  if m < 3 then m = m + 12; y = y - 1 end
  local h = (day + math.floor((13 * (m + 1)) / 5) + y + math.floor(y / 4)
    - math.floor(y / 100) + math.floor(y / 400)) % 7
  return (h + 5) % 7 + 1
end

-- Returns the year, month, day reached by moving delta days (may cross months/years)
function M.add_days(year, month, day, delta)
  if delta == 0 then return year, month, day end
  local d = day + delta
  while d < 1 do
    month = month - 1
    if month < 1 then month = 12; year = year - 1 end
    d = d + M.days_in_month(year, month)
  end
  while d > M.days_in_month(year, month) do
    d = d - M.days_in_month(year, month)
    month = month + 1
    if month > 12 then month = 1; year = year + 1 end
  end
  return year, month, d
end

-- Returns the year, month, day reached by moving delta months (day is clamped to month end)
function M.add_months(year, month, day, delta)
  local total = (year * 12) + (month - 1) + delta
  local ny = math.floor(total / 12)
  local nm = (total % 12) + 1
  return ny, nm, math.min(day, M.days_in_month(ny, nm))
end

function M.date_raw(year, month, day)
  return string.format("%04d%02d%02d", year, month, day)
end

local month_names = {
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December",
}

local weekday_names = { "Mo", "Tu", "We", "Th", "Fr", "Sa", "Su" }

-- Renders a month as a grid of 3-char-wide cells.
-- start_weekday is 1 (Monday) .. 7 (Sunday) for the first column.
-- Returns:
--   lines          buffer lines (title, weekday header, week rows)
--   weeks          rows of day numbers (nil for empty cells)
--   first_cell_row 1-based buffer row of the first week row
--   width          content width in columns
function M.month_grid(year, month, start_weekday)
  start_weekday = start_weekday or 1
  local width = 7 * 3

  local title = month_names[month] .. " " .. tostring(year)
  local pad   = math.max(0, width - #title)
  local left  = math.floor(pad / 2)
  local title_line = string.rep(" ", left) .. title .. string.rep(" ", pad - left)

  local header_parts = {}
  for i = 1, 7 do
    local idx = (start_weekday - 1 + i - 1) % 7 + 1
    header_parts[i] = weekday_names[idx] .. " "
  end

  local first_col = (M.day_of_week(year, month, 1) - start_weekday + 7) % 7 + 1
  local dim       = M.days_in_month(year, month)
  local weeks, week, col = {}, {}, first_col
  for d = 1, dim do
    week[col] = d
    col = col + 1
    if col == 8 then
      weeks[#weeks + 1] = week
      week, col = {}, 1
    end
  end
  if next(week) then weeks[#weeks + 1] = week end

  local lines = { title_line, table.concat(header_parts) }
  for _, w in ipairs(weeks) do
    local parts = {}
    for c = 1, 7 do
      parts[c] = w[c] and (string.format("%2d", w[c]) .. " ") or "   "
    end
    lines[#lines + 1] = table.concat(parts)
  end

  return {
    lines          = lines,
    weeks          = weeks,
    first_cell_row = 3,
    width          = width,
  }
end

return M
