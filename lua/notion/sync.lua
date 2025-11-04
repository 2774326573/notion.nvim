local api = require("notion.api")
local parser = require("notion.parser")
local util = require("notion.util")
local renderer = require("notion.renderer")
local notion = require("notion")

local M = {}

local function archive_existing(page_id, config)
  local blocks, err = api.retrieve_blocks(page_id, config)
  if not blocks then
    return nil, err
  end
  for _, block in ipairs(blocks) do
    api.update_block(block.id, config, { archived = true })
  end
  return blocks, nil
end

function M.sync_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not notion.ensure_token() then
    return
  end
  local config = notion.get_config()
  if not config then
    util.notify("[notion.nvim] Plugin not configured.", vim.log.levels.ERROR)
    return
  end

  local page_id = vim.b[bufnr].notion_page_id
  if not page_id then
    util.notify("[notion.nvim] Buffer has no associated Notion page id.", vim.log.levels.WARN)
    return
  end

  util.notify("[notion.nvim] Syncing page to Notion...", vim.log.levels.INFO)

  local blocks = parser.buffer_to_blocks(bufnr, config.tree_sitter.language)

  local _, archive_err = archive_existing(page_id, config)
  if archive_err then
    util.notify("[notion.nvim] Failed to archive existing blocks: " .. archive_err, vim.log.levels.ERROR)
    return
  end

  if #blocks > 0 then
    local _, append_err = api.append_children(page_id, config, blocks)
    if append_err then
      util.notify("[notion.nvim] Failed to append new blocks: " .. append_err, vim.log.levels.ERROR)
      return
    end
  end

  local refreshed, reload_err = api.retrieve_blocks(page_id, config)
  if not refreshed then
    util.notify("[notion.nvim] Synced but failed to reload blocks: " .. reload_err, vim.log.levels.WARN)
    return
  end

  vim.b[bufnr].notion_cached_blocks = refreshed
  util.notify("[notion.nvim] Page synced successfully.", vim.log.levels.INFO)
end

function M.reload_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not notion.ensure_token() then
    return
  end
  local config = notion.get_config()
  local page_id = vim.b[bufnr].notion_page_id
  if not page_id then
    return
  end
  local page, err = api.retrieve_page(page_id, config)
  if not page then
    util.notify("[notion.nvim] Failed to refresh page: " .. err, vim.log.levels.ERROR)
    return
  end
  local blocks, berr = api.retrieve_blocks(page_id, config)
  if not blocks then
    util.notify("[notion.nvim] Failed to fetch blocks: " .. berr, vim.log.levels.ERROR)
    return
  end

  local lines = renderer.blocks_to_markdown(blocks)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.b[bufnr].notion_cached_blocks = blocks
  vim.api.nvim_buf_set_option(bufnr, "modified", false)
end

return M
