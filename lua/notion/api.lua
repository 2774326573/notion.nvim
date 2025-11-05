local util = require("notion.util")

local M = {}

local base_url = "https://api.notion.com/v1/"

local function trim_nil(tbl)
  local out = {}
  for k, v in pairs(tbl) do
    if v ~= nil then
      out[k] = v
    end
  end
  return out
end

local function urlencode(value)
  return tostring(value)
    :gsub("\n", "")
    :gsub("([^%w%-_%.~])", function(c)
      return string.format("%%%02X", string.byte(c))
    end)
end

local function encode_query(query)
  if not query then
    return nil
  end
  local items = {}
  for key, value in pairs(query) do
    if value then
      table.insert(items, string.format("%s=%s", urlencode(key), urlencode(value)))
    end
  end
  return table.concat(items, "&")
end

local function max_time(option)
  if not option then
    return nil
  end
  return string.format("%.1f", option / 1000)
end

local function request(method, path, config, body, query)
  local url = base_url .. path
  local query_string = encode_query(query)
  if query_string and query_string ~= "" then
    url = url .. "?" .. query_string
  end

  local cmd = { "curl", "-sS", "-X", method, url }

  if config.timeout then
    table.insert(cmd, "--max-time")
    table.insert(cmd, max_time(config.timeout))
  end

  table.insert(cmd, "-H")
  table.insert(cmd, "Authorization: Bearer " .. config.token)
  table.insert(cmd, "-H")
  table.insert(cmd, "Notion-Version: " .. config.notion_version)

  if method == "GET" then
    -- Notion requires content-type header even for GETs when using curl
    table.insert(cmd, "-H")
    table.insert(cmd, "Content-Type: application/json")
  else
    table.insert(cmd, "-H")
    table.insert(cmd, "Content-Type: application/json")
  end

  if body ~= nil then
    table.insert(cmd, "-d")
    table.insert(cmd, util.json_encode(body))
  end

  local out, err = util.system(cmd)
  if not out then
    return nil, err
  end

  local decoded = util.json_decode(out)
  if not decoded then
    return nil, "Failed to decode Notion response."
  end
  if decoded.object == "error" then
    return nil, decoded.message or decoded.code
  end
  return decoded, nil
end

function M.list_pages(config, opts)
  if not config.database_id or config.database_id == "" then
    return nil, "Database ID is missing in configuration."
  end
  local base_body = {
    page_size = (opts and opts.page_size) or 20,
    filter = opts and opts.filter or nil,
    sorts = opts and opts.sorts or nil,
  }

  local results = {}
  local cursor = nil

  repeat
    local payload = {
      page_size = base_body.page_size,
      filter = base_body.filter,
      sorts = base_body.sorts,
      start_cursor = cursor,
    }
    local response, err = request(
      "POST",
      ("databases/%s/query"):format(util.norm_id(config.database_id)),
      config,
      trim_nil(payload)
    )
    if not response then
      return nil, err
    end
    for _, item in ipairs(response.results or {}) do
      table.insert(results, item)
    end
    cursor = response.has_more and response.next_cursor or nil
  until not cursor

  return results, nil
end

function M.retrieve_page(page_id, config)
  local response, err = request("GET", "pages/" .. util.norm_id(page_id), config)
  if not response then
    return nil, err
  end
  return response, nil
end

function M.retrieve_blocks(block_id, config)
  local accumulator = {}
  local cursor = nil

  repeat
    local response, err = request(
      "GET",
      ("blocks/%s/children"):format(util.norm_id(block_id)),
      config,
      nil,
      { page_size = "100", start_cursor = cursor }
    )
    if not response then
      return nil, err
    end
    for _, block in ipairs(response.results or {}) do
      table.insert(accumulator, block)
    end
    cursor = response.has_more and response.next_cursor or nil
  until not cursor

  return accumulator, nil
end

function M.append_children(block_id, config, children)
  local payload = { children = children }
  local response, err = request(
    "PATCH",
    ("blocks/%s/children"):format(util.norm_id(block_id)),
    config,
    payload
  )
  if not response then
    return nil, err
  end
  return response, nil
end

function M.update_block(block_id, config, payload)
  local response, err = request(
    "PATCH",
    ("blocks/%s"):format(util.norm_id(block_id)),
    config,
    payload
  )
  if not response then
    return nil, err
  end
  return response, nil
end

function M.delete_page(page_id, config)
  local response, err = request(
    "PATCH",
    "pages/" .. util.norm_id(page_id),
    config,
    { archived = true }
  )
  if not response then
    return nil, err
  end
  return response, nil
end

function M.create_page(config, payload)
  local props = payload.properties or {}
  local title_key = config.title_property or "Name"
  if props[title_key] == nil and props["Name"] then
    props[title_key] = props["Name"]
    props["Name"] = nil
  end
  payload.properties = props
  local response, err = request("POST", "pages", config, payload)
  if not response then
    return nil, err
  end
  return response, nil
end

return M
