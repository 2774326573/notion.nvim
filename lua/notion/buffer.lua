local api = require("notion.api")
local renderer = require("notion.renderer")
local util = require("notion.util")
local notion = require("notion")
local sync = require("notion.sync")

local M = {}

local function notion_text_object(text)
  return {
    type = "text",
    text = { content = text },
    plain_text = text,
    annotations = {
      bold = false,
      italic = false,
      strikethrough = false,
      underline = false,
      code = false,
      color = "default",
    },
  }
end

local function rich_text_plain(rich_text)
  local parts = {}
  for _, node in ipairs(rich_text or {}) do
    local value = node.plain_text or (node.text and node.text.content) or ""
    table.insert(parts, value)
  end
  return table.concat(parts, "")
end

local function clear_placeholder_heading(page_id, title, config)
  if not title or title == "" then
    return
  end
  local blocks = api.retrieve_blocks(page_id, config)
  if not blocks or #blocks ~= 1 then
    return
  end
  local block = blocks[1]
  if block.type ~= "heading_1" then
    return
  end
  local payload = block.heading_1 or {}
  local text = rich_text_plain(payload.rich_text)
  if vim.trim(text) ~= vim.trim(title) then
    return
  end
  api.update_block(block.id, config, { archived = true })
end

local function hydrate_children(block, config)
  if not block or not block.has_children then
    return
  end
  local block_type = block.type
  local payload = block[block_type]
  local children, err = api.retrieve_blocks(block.id, config)
  if not children then
    util.notify("[notion.nvim] Failed fetching child blocks: " .. err, vim.log.levels.WARN)
    return
  end
  payload.children = {}
  for _, child in ipairs(children) do
    hydrate_children(child, config)
    table.insert(payload.children, child)
  end
end

local function hydrate_block_tree(blocks, config)
  for _, block in ipairs(blocks or {}) do
    hydrate_children(block, config)
  end
end

local function sanitize_title(title)
  if not title or title == "" then
    return "Untitled"
  end
  local cleaned = title:gsub("[%c]", " ")
  cleaned = cleaned:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  if cleaned == "" then
    cleaned = "Untitled"
  end
  return cleaned
end

local function make_buffer_name(title, page_id)
  local base = sanitize_title(title)
  local short_id = nil
  if page_id then
    local normalized = util.norm_id(page_id)
    if normalized and normalized ~= "" then
      short_id = normalized:sub(1, math.min(#normalized, 8))
    end
  end
  if short_id then
    base = string.format("%s [%s]", base, short_id)
  end
  return "notion://" .. base
end

local function unique_buffer_name(name)
  if vim.fn.bufnr(name) == -1 then
    return name
  end
  local idx = 2
  while true do
    local candidate = string.format("%s (%d)", name, idx)
    if vim.fn.bufnr(candidate) == -1 then
      return candidate
    end
    idx = idx + 1
  end
end

local function find_buffer_by_page(page_id)
  if not page_id then
    return nil
  end
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.b[bufnr].notion_page_id == page_id then
      return bufnr
    end
  end
end

local function create_buffer(title, page_id)
  local bufnr = vim.api.nvim_create_buf(false, true)
  local name = make_buffer_name(title, page_id)
  name = unique_buffer_name(name)
  vim.api.nvim_buf_set_name(bufnr, name)
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].buftype = "acwrite"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].filetype = "markdown"
  vim.bo[bufnr].modifiable = true
  return bufnr
end

local function open_window(bufnr, config, opts)
  opts = opts or {}
  if config.ui.open_in_tab then
    vim.cmd("tab split")
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_buf_set_option(bufnr, "buflisted", true)
    vim.api.nvim_win_set_buf(win, bufnr)
    return
  end
  if config.ui.floating then
    local width = math.floor(vim.o.columns * config.ui.width)
    local height = math.floor(vim.o.lines * config.ui.height)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)
    vim.api.nvim_open_win(bufnr, true, {
      relative = "editor",
      row = row,
      col = col,
      width = width,
      height = height,
      border = config.ui.border or "single",
      title = opts.title,
      title_pos = "center",
    })
  else
    vim.api.nvim_set_current_buf(bufnr)
  end
end

function M.open_page(page_id)
  local config = notion.get_config()
  local page, perr = api.retrieve_page(page_id, config)
  if not page then
    util.notify("[notion.nvim] Failed loading page: " .. perr, vim.log.levels.ERROR)
    return
  end

  local blocks, berr = api.retrieve_blocks(page_id, config)
  if not blocks then
    util.notify("[notion.nvim] Failed loading blocks: " .. berr, vim.log.levels.ERROR)
    return
  end

  hydrate_block_tree(blocks, config)

  local title = renderer.extract_title(page, config.title_property)
  local lines = renderer.blocks_to_markdown(blocks)
  local existing = find_buffer_by_page(page.id)
  if existing then
    local target_name = make_buffer_name(title, page.id)
    local current_name = vim.api.nvim_buf_get_name(existing)
    if current_name ~= target_name then
      local name = target_name
      local found = vim.fn.bufnr(target_name)
      if found ~= -1 and found ~= existing then
        name = unique_buffer_name(target_name)
      end
      vim.api.nvim_buf_set_name(existing, name)
    end
    vim.api.nvim_buf_set_lines(existing, 0, -1, false, lines)
    vim.b[existing].notion_page_title = title
    vim.b[existing].notion_cached_blocks = blocks
    vim.api.nvim_buf_set_option(existing, "modified", false)
    open_window(existing, config, { title = title })
    return
  end

  local bufnr = create_buffer(title, page.id)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.b[bufnr].notion_page_id = page.id
  vim.b[bufnr].notion_page_title = title
  vim.b[bufnr].notion_cached_blocks = blocks
  vim.api.nvim_buf_set_option(bufnr, "modified", false)

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = bufnr,
    callback = function()
      sync.sync_buffer(bufnr)
      vim.api.nvim_buf_set_option(bufnr, "modified", false)
    end,
  })

  open_window(bufnr, config, { title = title })
end

function M.new_page()
  local config = notion.get_config()
  if not config.database_id or config.database_id == "" then
    util.notify("[notion.nvim] Configure `database_id` before creating pages.", vim.log.levels.ERROR)
    return
  end

  vim.ui.input({ prompt = "Notion page title: " }, function(input)
    if not input or input == "" then
      util.notify("[notion.nvim] Aborted creating page.", vim.log.levels.INFO)
      return
    end
    local title_key = notion.ensure_title_property() or "Name"
    local current_db = notion.get_current_database()
    local db_id = (current_db and current_db.id) or config.database_id
    if type(db_id) ~= "string" or db_id == "" then
      util.notify("[notion.nvim] Active database is invalid. Select a database before creating pages.", vim.log.levels.ERROR)
      return
    end
    local properties = {
      [title_key] = {
        title = { notion_text_object(input) },
      },
    }
    local payload = {
      parent = { database_id = util.norm_id(db_id) },
      properties = properties,
    }
    local page, err = api.create_page(config, payload)
    if not page then
      util.notify("[notion.nvim] Failed creating page: " .. err, vim.log.levels.ERROR)
      return
    end
    clear_placeholder_heading(page.id, input, config)
    util.notify("[notion.nvim] Page created. Opening buffer...", vim.log.levels.INFO)
    M.open_page(page.id)
  end)
end

return M

