local renderer = require("notion.renderer")
local buffer = require("notion.buffer")
local util = require("notion.util")
local notion = require("notion")

local M = {}

function M.select_page(pages, opts)
  if not vim.tbl_islist(pages) then
    opts = pages or {}
    local fetched = notion.fetch_pages(opts)
    if not fetched then
      return
    end
    pages = fetched
  else
    opts = opts or {}
  end

  if not pages or #pages == 0 then
    util.notify("[notion.nvim] No pages returned from Notion query.", vim.log.levels.INFO)
    return
  end
  local config = notion.get_config()

  local items = {}
  for _, page in ipairs(pages) do
    local title = renderer.extract_title(page, config.title_property)
    table.insert(items, {
      label = title,
      id = page.id,
      page = page,
    })
  end

  vim.ui.select(items, {
    prompt = "Select Notion page",
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if not choice then
      return
    end
    buffer.open_page(choice.id)
  end)
end

function M.new_page()
  buffer.new_page()
end

return M
