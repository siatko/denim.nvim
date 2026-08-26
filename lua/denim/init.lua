local M = {}

function M.setup(opts)
  require("denim.config").setup(opts)
  require("denim.notes").ensure_notes_dir()

  local keymaps = require("denim.config").options.keymaps
  if keymaps then
    if keymaps.new_note then
      vim.keymap.set("n", keymaps.new_note, function()
        require("denim.notes").new_note()
      end, { desc = "denim: new note" })
    end
    if keymaps.capture then
      vim.keymap.set("n", keymaps.capture, function()
        require("denim.notes").capture()
      end, { desc = "denim: quick capture" })
    end
    if keymaps.new_from_template then
      vim.keymap.set("n", keymaps.new_from_template, function()
        require("denim.notes").new_note_from_template()
      end, { desc = "denim: new note from template" })
    end
    if keymaps.new_template then
      vim.keymap.set("n", keymaps.new_template, function()
        require("denim.notes").new_template()
      end, { desc = "denim: new template" })
    end
    if keymaps.search_templates then
      vim.keymap.set("n", keymaps.search_templates, function()
        require("denim.telescope").search_templates()
      end, { desc = "denim: browse and edit templates" })
    end
    if keymaps.search_notes then
      vim.keymap.set("n", keymaps.search_notes, function()
        require("denim.telescope").search_notes()
      end, { desc = "denim: search notes" })
    end
    if keymaps.search_content then
      vim.keymap.set("n", keymaps.search_content, function()
        require("denim.telescope").search_content()
      end, { desc = "denim: search note contents" })
    end
    if keymaps.search_tags then
      vim.keymap.set("n", keymaps.search_tags, function()
        require("denim.telescope").search_tags()
      end, { desc = "denim: search tags" })
    end
    if keymaps.search_untagged then
      vim.keymap.set("n", keymaps.search_untagged, function()
        require("denim.telescope").search_untagged()
      end, { desc = "denim: search untagged notes" })
    end
    if keymaps.rename_tag then
      vim.keymap.set("n", keymaps.rename_tag, function()
        require("denim.telescope").rename_tag()
      end, { desc = "denim: rename tag across all notes" })
    end
    if keymaps.paste_image then
      vim.keymap.set("n", keymaps.paste_image, function()
        require("denim.notes").paste_image()
      end, { desc = "denim: paste image from clipboard" })
    end
    if keymaps.insert_link then
      vim.keymap.set("n", keymaps.insert_link, function()
        require("denim.telescope").insert_link()
      end, { desc = "denim: insert link to note" })
    end
    if keymaps.insert_url_link then
      vim.keymap.set("n", keymaps.insert_url_link, function()
        require("denim.notes").insert_url_link()
      end, { desc = "denim: insert URL link from clipboard" })
    end
    if keymaps.backlinks then
      vim.keymap.set("n", keymaps.backlinks, function()
        require("denim.telescope").backlinks()
      end, { desc = "denim: show backlinks" })
    end
    if keymaps.refactor then
      vim.keymap.set("n", keymaps.refactor, function()
        require("denim.notes").refactor()
      end, { desc = "denim: refactor current note" })
    end
    if keymaps.delete_notes then
      vim.keymap.set("n", keymaps.delete_notes, function()
        require("denim.telescope").delete_notes()
      end, { desc = "denim: delete notes" })
    end
    if keymaps.cycle_workflow then
      vim.keymap.set("n", keymaps.cycle_workflow, function()
        require("denim.notes").cycle_workflow()
      end, { desc = "denim: cycle workflow state (none → todo → done → none)" })
    end
    if keymaps.open_index then
      vim.keymap.set("n", keymaps.open_index, function()
        require("denim.index").open()
      end, { desc = "denim: open notes index" })
    end
    if keymaps.open_stats then
      vim.keymap.set("n", keymaps.open_stats, function()
        require("denim.stats").open()
      end, { desc = "denim: open notes statistics" })
    end
  end

  local ok, wk = pcall(require, "which-key")
  if ok then
    wk.add({
      { "<leader>n",  group = "notes" },
      { "<leader>nt", group = "templates" },
      { "<leader>ng", group = "tags" },
      { "<leader>nv", group = "views" },
    })
  end

  local notes_dir = require("denim.config").options.notes_dir
  vim.api.nvim_create_augroup("denim", { clear = true })
  vim.api.nvim_create_autocmd("BufEnter", {
    group = "denim",
    pattern = "*.md",
    callback = function()
      if vim.startswith(vim.fn.resolve(vim.fn.expand("%:p")), notes_dir) then
        vim.keymap.set("n", "<CR>", function()
          require("denim.notes").follow_link()
        end, { buffer = true, desc = "denim: follow link" })
        vim.keymap.set("n", "<C-LeftMouse>", function()
          require("denim.notes").follow_link()
        end, { buffer = true, desc = "denim: follow link" })
      end
    end,
  })

  vim.api.nvim_create_user_command("DenimInsertLink", function()
    require("denim.telescope").insert_link()
  end, { desc = "Insert link to another note" })
  vim.api.nvim_create_user_command("DenimInsertUrlLink", function()
    require("denim.notes").insert_url_link()
  end, { desc = "Insert URL link from clipboard" })
  vim.api.nvim_create_user_command("DenimBacklinks", function()
    require("denim.telescope").backlinks()
  end, { desc = "Show backlinks to current note" })
  vim.api.nvim_create_user_command("DenimRefactor", function()
    require("denim.notes").refactor()
  end, { desc = "Refactor current note (rename + retag)" })
  vim.api.nvim_create_user_command("DenimCapture", function()
    require("denim.notes").capture()
  end, { desc = "Quick capture - title prompt then floating editor" })
  vim.api.nvim_create_user_command("DenimNew", function()
    require("denim.notes").new_note()
  end, { desc = "Create a new note in inbox" })
  vim.api.nvim_create_user_command("DenimNewFromTemplate", function()
    require("denim.notes").new_note_from_template()
  end, { desc = "Create a new note from a template" })
  vim.api.nvim_create_user_command("DenimNewTemplate", function()
    require("denim.notes").new_template()
  end, { desc = "Create a new template" })
  vim.api.nvim_create_user_command("DenimTemplates", function()
    require("denim.telescope").search_templates()
  end, { desc = "Browse and edit templates" })
  vim.api.nvim_create_user_command("DenimSearch", function()
    require("denim.telescope").search_notes()
  end, { desc = "Search notes by filename" })
  vim.api.nvim_create_user_command("DenimSearchContent", function()
    require("denim.telescope").search_content()
  end, { desc = "Search note contents" })
  vim.api.nvim_create_user_command("DenimTags", function()
    require("denim.telescope").search_tags()
  end, { desc = "Search tags in notes" })
  vim.api.nvim_create_user_command("DenimUntagged", function()
    require("denim.telescope").search_untagged()
  end, { desc = "List notes without tags" })
  vim.api.nvim_create_user_command("DenimRenameTag", function()
    require("denim.telescope").rename_tag()
  end, { desc = "Rename a tag across all notes" })
  vim.api.nvim_create_user_command("DenimPasteImage", function()
    require("denim.notes").paste_image()
  end, { desc = "Paste image from clipboard" })
  vim.api.nvim_create_user_command("DenimCycle", function()
    require("denim.notes").cycle_workflow()
  end, { desc = "Cycle workflow state: none → todo → done → none" })
  vim.api.nvim_create_user_command("DenimDelete", function()
    require("denim.telescope").delete_notes()
  end, { desc = "Delete notes (multiselect picker with confirmation)" })
  vim.api.nvim_create_user_command("DenimIndex", function()
    require("denim.index").open()
  end, { desc = "Open notes index" })
  vim.api.nvim_create_user_command("DenimStats", function()
    require("denim.stats").open()
  end, { desc = "Open notes statistics" })
end

return M
