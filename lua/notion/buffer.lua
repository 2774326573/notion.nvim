local api = require("notion.api")
local renderer = require("notion.renderer")
local util = require("notion.util")
local notion = require("notion")

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

local function create_buffer(title)
  local bufnr = vim.api.nvim_create_buf(false, true)
  local name = ("notion://%s"):format(title or "page")
  vim.api.nvim_buf_set_name(bufnr, name)
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].filetype = "markdown"
  vim.bo[bufnr].modifiable = true
  return bufnr
end

local function open_window(bufnr, config, opts)
  opts = opts or {}
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

  local bufnr = create_buffer(title)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.b[bufnr].notion_page_id = page.id
  vim.b[bufnr].notion_page_title = title
  vim.b[bufnr].notion_cached_blocks = blocks
  vim.api.nvim_buf_set_option(bufnr, "modified", false)

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
    local payload = {
      parent = { database_id = util.norm_id(config.database_id) },
      properties = {
        [config.title_property] = {
          title = { notion_text_object(input) },
        },
      },
    }
    local page, err = api.create_page(config, payload)
    if not page then
      util.notify("[notion.nvim] Failed creating page: " .. err, vim.log.levels.ERROR)
      return
    end
    util.notify("[notion.nvim] Page created. Opening buffer…", vim.log.levels.INFO)
    M.open_page(page.id)
  end)
end

return M
