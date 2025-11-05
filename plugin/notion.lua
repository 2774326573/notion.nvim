if vim.g.loaded_notion_plugin then
  return
end
vim.g.loaded_notion_plugin = true

local notion = require("notion")

vim.api.nvim_create_user_command("NotionList", function(opts)
  notion.list_pages({
    page_size = tonumber(opts.args) or nil,
  })
end, {
  nargs = "?",
  desc = "List pages from the configured Notion database",
})

vim.api.nvim_create_user_command("NotionOpen", function(opts)
  notion.open_page(opts.args)
end, {
  nargs = 1,
  complete = function()
    return {}
  end,
  desc = "Open a Notion page by ID",
})

vim.api.nvim_create_user_command("NotionNew", function()
  notion.new_page()
end, {
  nargs = 0,
  desc = "Create a new page in the configured Notion database",
})

vim.api.nvim_create_user_command("NotionSync", function()
  notion.sync_current_buffer()
end, {
  nargs = 0,
  desc = "Sync current buffer back to Notion",
})

vim.api.nvim_create_user_command("NotionSetToken", function()
  notion.set_token()
end, {
  nargs = 0,
  desc = "Set Notion API token",
})

vim.api.nvim_create_user_command("NotionRefreshPages", function(opts)
  notion.refresh_pages(opts)
end, {
  nargs = "?",
  desc = "Refresh the cached page list for the current database",
})

vim.api.nvim_create_user_command("NotionSelectDatabase", function()
  notion.select_database()
end, {
  nargs = 0,
  desc = "Select active Notion database",
})
