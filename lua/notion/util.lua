local M = {}

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

function M.norm_id(id)
  if not id then
    return nil
  end
  return id:gsub("-", "")
end

return M
