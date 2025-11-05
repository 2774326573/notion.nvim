local api = require("notion.api")
local parser = require("notion.parser")
local util = require("notion.util")
local renderer = require("notion.renderer")
local notion = require("notion")

local M = {}

local function archive_existing_async(page_id, config, callback)
  api.retrieve_blocks_async(page_id, config, function(blocks, err)
    if not blocks then
      callback(nil, err)
      return
    end
    local index = 1
    local total = #blocks
    if total == 0 then
      callback({}, nil)
      return
    end
    local function archive_next()
      if index > total then
        callback(blocks, nil)
        return
      end
      local block = blocks[index]
      index = index + 1
      api.update_block_async(block.id, config, { archived = true }, function(_, update_err)
        if update_err then
          callback(nil, update_err)
          return
        end
        archive_next()
      end)
    end
    archive_next()
  end)
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

  if vim.b[bufnr].notion_syncing then
    util.notify("[notion.nvim] Sync already in progress for this buffer.", vim.log.levels.WARN)
    return
  end

  vim.b[bufnr].notion_syncing = true

  local function finish()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.b[bufnr].notion_syncing = nil
    end
  end

  local function fail(message, level)
    finish()
    util.notify(message, level or vim.log.levels.ERROR)
  end

  util.notify("[notion.nvim] Syncing page to Notion...", vim.log.levels.INFO)

  local blocks = parser.buffer_to_blocks(bufnr, config.tree_sitter.language)
  if #blocks == 0 then
    local raw = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
    if raw:match("%S") then
      fail(
        "[notion.nvim] No blocks were generated from the buffer. Ensure the markdown tree-sitter parser is installed.",
        vim.log.levels.ERROR
      )
      return
    end
  end

  local function refresh_blocks()
    api.retrieve_blocks_async(page_id, config, function(refreshed, reload_err)
      if not refreshed then
        fail("[notion.nvim] Synced but failed to reload blocks: " .. reload_err, vim.log.levels.WARN)
        return
      end
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.b[bufnr].notion_cached_blocks = refreshed
      end
      finish()
      util.notify("[notion.nvim] Page synced successfully.", vim.log.levels.INFO)
    end)
  end

  local function append_new_blocks()
    if #blocks == 0 then
      refresh_blocks()
      return
    end
    api.append_children_async(page_id, config, blocks, function(_, append_err)
      if append_err then
        fail("[notion.nvim] Failed to append new blocks: " .. append_err, vim.log.levels.ERROR)
        return
      end
      refresh_blocks()
    end)
  end

  archive_existing_async(page_id, config, function(_, archive_err)
    if archive_err then
      fail("[notion.nvim] Failed to archive existing blocks: " .. archive_err, vim.log.levels.ERROR)
      return
    end
    append_new_blocks()
  end)
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
