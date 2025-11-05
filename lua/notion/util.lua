local M = {}

local function trim(value)
  if not value then
    return ""
  end
  if vim.trim then
    return vim.trim(value)
  end
  return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

function M.json_encode(value)
  if vim.json and vim.json.encode then
    return vim.json.encode(value)
  end
  return vim.fn.json_encode(value)
end

function M.json_decode(value)
  if value == nil or value == "" then
    return nil
  end
  if vim.json and vim.json.decode then
    return vim.json.decode(value)
  end
  return vim.fn.json_decode(value)
end

function M.notify(msg, level)
  vim.schedule(function()
    vim.notify(msg, level or vim.log.levels.INFO)
  end)
end

function M.system(cmd)
  if type(cmd) ~= "table" then
    error("system command expects table")
  end

  if vim.system then
    local obj = vim.system(cmd, { text = true }):wait()
    if obj.code ~= 0 then
      return nil, table.concat({
        obj.stderr or "",
        obj.stdout or "",
      }, "\n")
    end
    return obj.stdout, nil
  end

  local result = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    return nil, result
  end
  return result, nil
end

function M.system_async(cmd, callback)
  if type(cmd) ~= "table" then
    error("system command expects table")
  end
  if type(callback) ~= "function" then
    error("system_async expects callback function")
  end

  local function dispatch(stdout, err)
    vim.schedule(function()
      callback(stdout, err)
    end)
  end

  if vim.system then
    local handle = vim.system(cmd, { text = true }, function(obj)
      if obj.code ~= 0 then
        local message = table.concat({
          obj.stderr or "",
          obj.stdout or "",
        }, "\n")
        dispatch(nil, trim(message))
      else
        dispatch(obj.stdout or "", nil)
      end
    end)
    if not handle then
      dispatch(nil, "Failed to start system command")
    end
    return
  end

  local stdout_chunks = {}
  local stderr_chunks = {}
  local job = vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if not data then
        return
      end
      local chunk = table.concat(data, "\n")
      if chunk ~= "" then
        table.insert(stdout_chunks, chunk)
      end
    end,
    on_stderr = function(_, data)
      if not data then
        return
      end
      local chunk = table.concat(data, "\n")
      if chunk ~= "" then
        table.insert(stderr_chunks, chunk)
      end
    end,
    on_exit = function(_, code)
      if code ~= 0 then
        local message = table.concat({
          table.concat(stderr_chunks, "\n"),
          table.concat(stdout_chunks, "\n"),
        }, "\n")
        dispatch(nil, trim(message))
      else
        dispatch(table.concat(stdout_chunks, "\n"), nil)
      end
    end,
  })

  if job <= 0 then
    dispatch(nil, "Failed to start system command")
  end
end

function M.norm_id(id)
  if not id then
    return nil
  end
  return id:gsub("-", "")
end

return M
