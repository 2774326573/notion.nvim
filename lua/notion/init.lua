local M = {}

local state = {
  config = nil,
  autocmd_id = nil,
  token_warned = false,
}

local defaults = {
  token = nil,
  token_env = "NOTION_API_TOKEN",
  database_id = nil,
  title_property = "Name",
  notion_version = "2022-06-28",
  timeout = 20000,
  tree_sitter = {
    language = "markdown",
  },
  sync = {
    auto_write = true,
  },
  ui = {
    floating = true,
    open_in_tab = false,
    width = 0.8,
    height = 0.8,
    border = "rounded",
  },
}

local function merge_tables(base, overrides)
  if overrides == nil then
    return base
  end
  local result = vim.deepcopy(base)
  for k, v in pairs(overrides) do
    if type(v) == "table" and type(result[k] or false) == "table" then
      result[k] = merge_tables(result[k], v)
    else
      result[k] = v
    end
  end
  return result
end

local function resolve_token(config)
  if config.token and config.token ~= "" then
    state.token_warned = false
    return config.token
  end
  if config.token_env then
    local env_token = vim.env[config.token_env]
    if env_token and env_token ~= "" then
      config.token = env_token
      state.token_warned = false
      return env_token
    end
  end
  return nil
end

local function ensure_setup()
  if state.config ~= nil then
    return true
  end
  vim.notify("[notion.nvim] Setup has not been called yet.", vim.log.levels.ERROR)
  return false
end

local function ensure_token(config, opts)
  if not resolve_token(config) then
    if not (opts and opts.silent) then
      if not state.token_warned then
        local msg = "[notion.nvim] Notion API token is missing. Set `token` in setup() or provide it via $" .. (config.token_env or "NOTION_API_TOKEN") .. "."
        vim.notify(msg, vim.log.levels.WARN)
        state.token_warned = true
      end
    end
    return false
  end
  return true
end

function M.setup(opts)
  local config = merge_tables(defaults, opts or {})
  state.config = config
  state.token_warned = false

  ensure_token(config, { silent = true })

  if state.autocmd_id then
    pcall(vim.api.nvim_del_autocmd, state.autocmd_id)
    state.autocmd_id = nil
  end

  if config.sync.auto_write then
    local group = vim.api.nvim_create_augroup("NotionAutoSync", { clear = true })
    state.autocmd_id = vim.api.nvim_create_autocmd("BufWritePost", {
      group = group,
      callback = function(args)
        local bufnr = args.buf
        if vim.b[bufnr].notion_page_id then
          require("notion.sync").sync_buffer(bufnr)
        end
      end,
    })
  end
end

function M.get_config()
  return state.config
end

function M.ensure_token(opts)
  if not ensure_setup() then
    return false
  end
  return ensure_token(state.config, opts)
end

function M.list_pages(opts)
  if not ensure_setup() then
    return
  end
  local config = state.config
  if not ensure_token(config) then
    return
  end
  require("notion.ui").select_page(opts or {})
end

function M.open_page(page_id)
  if not ensure_setup() then
    return
  end
  local config = state.config
  if not ensure_token(config) then
    return
  end
  if not page_id or page_id == "" then
    vim.notify("[notion.nvim] Provide a page ID to :NotionOpen.", vim.log.levels.ERROR)
    return
  end
  require("notion.buffer").open_page(page_id)
end

function M.new_page()
  if not ensure_setup() then
    return
  end
  if not ensure_token(state.config) then
    return
  end
  require("notion.ui").new_page()
end

function M.sync_current_buffer()
  if not ensure_setup() then
    return
  end
  if not ensure_token(state.config) then
    return
  end
  local bufnr = vim.api.nvim_get_current_buf()
  if not vim.b[bufnr].notion_page_id then
    vim.notify("[notion.nvim] Current buffer is not linked to a Notion page.", vim.log.levels.WARN)
    return
  end
  require("notion.sync").sync_buffer(bufnr)
end

return M
