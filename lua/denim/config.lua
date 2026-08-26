local M = {}

M.defaults = {
  notes_dir = "~/notes",
  calendar = {
    -- 1 = Monday .. 7 = Sunday, for the first column of the calendar
    start_weekday = 1,
  },
  workflow = {
    todo    = "todo",
    done    = "done",
    capture = "quick",
    daily   = "daily",
  },
  keymaps = {
    new_note          = "<leader>nn",
    daily_note        = "<leader>nd", -- opens the daily note calendar (Enter opens today)
    capture           = "<leader>nq",
    search_notes      = "<leader>nf",
    search_content    = "<leader>ns",
    refactor          = "<leader>nr",
    paste_image       = "<leader>np",
    insert_link       = "<leader>nl",
    insert_url_link   = "<leader>nu",
    backlinks         = "<leader>nb",
    new_from_template = "<leader>ntn",
    new_template      = "<leader>ntN",
    search_templates  = "<leader>nte",
    search_tags       = "<leader>ngs",
    search_untagged   = "<leader>ngu",
    rename_tag        = "<leader>ngr",
    delete_notes      = "<leader>nD",
    cycle_workflow    = "<leader>nx",
    open_index        = "<leader>nvi",
    open_stats        = "<leader>nvs",
  },
}

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
  M.options.notes_dir = vim.fn.resolve(vim.fn.expand(M.options.notes_dir))
end

return M
