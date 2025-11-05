local M = {}

local api = require("notion.api")
local util = require("notion.util")
local os_time = os.time

local state = {
  config = nil,
  autocmd_id = nil,
  token_warned = false,
  databases = {},
  current_database = nil,
  default_title_property = nil,
  page_cache = {},
}

local data_root = (vim.fn.stdpath("data") or ".") .. "/notion.nvim"
local last_database_path = data_root .. "/last_database.txt"
local token_path = data_root .. "/token.txt"
local skip_prompt_path = data_root .. "/skip_token_prompt.txt"

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
  databases = nil,
  default_database = nil,
  cache = {
    ttl = 60,
  },
}

local function ensure_data_dir()
  local dir = vim.fn.fnamemodify(last_database_path, ":h")
  if dir and dir ~= "" then
    pcall(vim.fn.mkdir, dir, "p")
  end
end

local function load_last_database()
  local ok, content = pcall(function()
    local fd = io.open(last_database_path, "r")
    if not fd then
      return nil
    end
    local data = fd:read("*l")
    fd:close()
    if not data or data == "" then
      return nil
    end
    return vim.trim(data)
  end)
  if ok then
    return content
  end
end

local function save_last_database(id)
  if not id or id == "" then
    return
  end
  ensure_data_dir()
  pcall(function()
    local fd = assert(io.open(last_database_path, "w"))
    fd:write(id)
    fd:close()
  end)
end

local function load_token()
  local ok, content = pcall(function()
    local fd = io.open(token_path, "r")
    if not fd then
      return nil
    end
    local data = fd:read("*l")
    fd:close()
    if not data or data == "" then
      return nil
    end
    return vim.trim(data)
  end)
  if ok then
    return content
  end
end

local function load_skip_prompt()
  local ok, flag = pcall(function()
    local fd = io.open(skip_prompt_path, "r")
    if not fd then
      return nil
    end
    local data = fd:read("*l")
    fd:close()
    return data == "1"
  end)
  if ok and flag then
    return true
  end
  return false
end

local function save_skip_prompt(enabled)
  ensure_data_dir()
  if enabled then
    pcall(function()
      local fd = assert(io.open(skip_prompt_path, "w"))
      fd:write("1")
      fd:close()
    end)
  else
    pcall(function()
      os.remove(skip_prompt_path)
    end)
  end
end

local function save_token(token)
  if not token or token == "" then
    return
  end
  ensure_data_dir()
  pcall(function()
    local fd = assert(io.open(token_path, "w"))
    fd:write(token)
    fd:close()
  end)
  save_skip_prompt(false)
end

local function normalize_database_entry(db)
  if type(db) == "string" then
    return { id = db }
  elseif type(db) == "table" then
    local id = db.id or db.database_id or db[1]
    if not id or id == "" then
      return nil
    end
    return {
      id = id,
      name = db.name or db.label or db.title or id,
      title_property = db.title_property,
    }
  end
end

local function normalize_databases(config)
  local entries = {}
  local seen = {}

  local function push(entry)
    if not entry or not entry.id or entry.id == "" or seen[entry.id] then
      return
    end
    seen[entry.id] = true
    entry.name = entry.name or entry.id
    entry.title_property = entry.title_property or config.title_property
    table.insert(entries, entry)
  end

  if type(config.database_id) == "table" then
    for _, db in ipairs(config.database_id) do
      push(normalize_database_entry(db))
    end
  elseif type(config.database_id) == "string" and config.database_id ~= "" then
    push({ id = config.database_id, title_property = config.title_property })
  end

  if type(config.databases) == "table" then
    for _, db in ipairs(config.databases) do
      push(normalize_database_entry(db))
    end
  end

  return entries
end

local function apply_database(entry)
  if not entry or not entry.id then
    return false
  end
  local title_prop = entry.title_property or state.default_title_property or state.config.title_property
  state.config.database_id = entry.id
  state.config.title_property = title_prop
  state.current_database = {
    id = entry.id,
    name = entry.name or entry.id,
    title_property = title_prop,
  }
  save_last_database(entry.id)
  return true
end

local function find_database(identifier)
  if not identifier then
    return nil
  end
  if type(identifier) == "number" then
    return state.databases[identifier]
  end
  for _, db in ipairs(state.databases) do
    if db.id == identifier or db.name == identifier then
      return db
    end
  end
end

local function ensure_database_selected(opts)
  opts = opts or {}
  if state.config.database_id and state.config.database_id ~= "" then
    return true
  end
  if #state.databases == 0 then
    if not opts.silent then
      vim.notify("[notion.nvim] No database configured. Set `database_id` or `databases` in setup().", vim.log.levels.ERROR)
    end
    return false
  end
  return apply_database(state.databases[1])
end

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
  local file_token = load_token()
  if file_token and file_token ~= "" then
    config.token = file_token
    state.token_warned = false
    return file_token
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
  local token = resolve_token(config)
  if token then
    if state.token_warned then
      state.token_warned = false
      save_skip_prompt(false)
    end
    return true
  end
  if state.token_warned then
    return false
  end
  if opts and opts.autoprompt == false then
    return false
  end
  M.set_token({ silent = opts and opts.silent, autoprompt = true })
  return false
end

function M.setup(opts)
  local config = merge_tables(defaults, opts or {})
  state.config = config
  state.token_warned = load_skip_prompt()
  state.default_title_property = config.title_property
  state.databases = normalize_databases(config)
  config.databases = state.databases

  local remembered_database = load_last_database()

  local initial_database = nil
  if remembered_database then
    initial_database = find_database(remembered_database)
  end
  if not initial_database and config.default_database then
    initial_database = find_database(config.default_database)
  elseif not initial_database and type(config.database_id) == "string" and config.database_id ~= "" then
    initial_database = find_database(config.database_id)
  end
  if not initial_database and #state.databases > 0 then
    initial_database = state.databases[1]
  end
  if not initial_database and type(config.database_id) == "string" and config.database_id ~= "" then
    initial_database = { id = config.database_id, title_property = config.title_property }
  end
  if initial_database then
    apply_database(initial_database)
  else
    state.current_database = nil
    state.config.database_id = nil
  end

  ensure_token(config, { silent = true, autoprompt = false })

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

function M.fetch_pages(opts)
  opts = opts or {}
  if not ensure_setup() then
    return nil, "setup"
  end
  local config = state.config
  if not ensure_token(config) then
    return nil, "token"
  end
  if not ensure_database_selected(opts) then
    return nil, "database"
  end

  local db_id = config.database_id
  local cache_entry = state.page_cache[db_id]
  local ttl = config.cache and config.cache.ttl
  local now = os_time()
  if cache_entry and not opts.refresh then
    if ttl == nil then
      return cache_entry.items
    elseif ttl > 0 and (now - cache_entry.time) <= ttl then
      return cache_entry.items
    end -- ttl <= 0 disables caching
  end

  local query_opts = opts
  if opts.refresh ~= nil then
    query_opts = vim.tbl_deep_extend("force", {}, opts)
    query_opts.refresh = nil
  end

  local pages, err = api.list_pages(config, query_opts)
  if not pages then
    if err then
      util.notify("[notion.nvim] Failed listing pages: " .. err, vim.log.levels.ERROR)
    end
    return nil, err
  end
  state.page_cache[db_id] = { items = pages, time = now }
  return pages
end

function M.clear_page_cache(database_id)
  if not ensure_setup() then
    return
  end
  local db = database_id or (state.current_database and state.current_database.id)
  if not db then
    return
  end
  state.page_cache[db] = nil
end

function M.list_pages(opts)
  local pages = M.fetch_pages(opts)
  if not pages then
    return
  end
  require("notion.ui").select_page(pages, opts or {})
end

function M.refresh_pages(opts)
  opts = opts or {}
  if not ensure_setup() then
    return
  end
  if not ensure_database_selected(opts) then
    return
  end
  M.clear_page_cache()
  M.list_pages(vim.tbl_deep_extend("force", {}, opts, { refresh = true }))
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
  if not ensure_database_selected() then
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

function M.delete_page(page_id)
  if not ensure_setup() then
    return
  end
  local config = state.config
  if not ensure_token(config) then
    return
  end
  if not ensure_database_selected() then
    return
  end

  local bufnr
  if not page_id or page_id == "" then
    bufnr = vim.api.nvim_get_current_buf()
    page_id = vim.b[bufnr] and vim.b[bufnr].notion_page_id or nil
  end

  if not page_id or page_id == "" then
    util.notify("[notion.nvim] No Notion page ID available for deletion.", vim.log.levels.WARN)
    return
  end

  local _, err = api.delete_page(page_id, config)
  if err then
    util.notify("[notion.nvim] Failed deleting page: " .. err, vim.log.levels.ERROR)
    return
  end

  local db_id = config.database_id
  local norm = util.norm_id(page_id)
  local cache = state.page_cache[db_id]
  if cache then
    for idx = #cache.items, 1, -1 do
      local item = cache.items[idx]
      if util.norm_id(item.id or "") == norm then
        table.remove(cache.items, idx)
        break
      end
    end
  end

  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end

  util.notify("[notion.nvim] Page archived in Notion.", vim.log.levels.INFO)
end

function M.get_databases()
  if not ensure_setup() then
    return {}
  end
  return vim.deepcopy(state.databases or {})
end

function M.get_current_database()
  if not ensure_setup() then
    return nil
  end
  return state.current_database and vim.deepcopy(state.current_database) or nil
end

function M.use_database(identifier)
  if not ensure_setup() then
    return false
  end
  if type(identifier) == "table" and identifier.id then
    return apply_database(identifier)
  end
  local entry = find_database(identifier)
  if not entry then
    vim.notify("[notion.nvim] Database not found: " .. tostring(identifier), vim.log.levels.WARN)
    return false
  end
  return apply_database(entry)
end

function M.select_database()
  if not ensure_setup() then
    return
  end
  if #state.databases == 0 then
    vim.notify("[notion.nvim] No databases configured.", vim.log.levels.WARN)
    return
  end
  local items = {}
  for index, db in ipairs(state.databases) do
    items[index] = {
      index = index,
      db = db,
      label = db.name or db.id,
    }
  end
  vim.ui.select(items, {
    prompt = "Select Notion database",
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if not choice then
      return
    end
    apply_database(choice.db)
    vim.notify("[notion.nvim] Switched to database: " .. (choice.db.name or choice.db.id), vim.log.levels.INFO)
  end)
end

function M.set_token(opts)
  opts = opts or {}
  if not ensure_setup() then
    return
  end
  vim.ui.input({
    prompt = "Notion API token: ",
    default = state.config.token or "",
  }, function(value)
    if value and value ~= "" then
      save_token(value)
      state.config.token = value
      state.token_warned = false
      if not opts.silent then
        vim.notify("[notion.nvim] Token saved.", vim.log.levels.INFO)
      end
    else
      if opts.autoprompt then
        state.token_warned = true
        save_skip_prompt(true)
      end
      if not opts.silent then
        local msg = opts.autoprompt and "[notion.nvim] Token is required. Use :NotionSetToken when you are ready." or "[notion.nvim] Token not updated."
        vim.notify(msg, vim.log.levels.WARN)
      end
    end
  end)
end

return M
