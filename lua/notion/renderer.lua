local util = require("notion.util")

local M = {}

local function apply_annotations(text, annotations)
  if not annotations then
    return text
  end
  local value = text
  if annotations.code then
    value = "`" .. value .. "`"
  else
    if annotations.bold then
      value = "**" .. value .. "**"
    end
    if annotations.italic then
      value = "_" .. value .. "_"
    end
    if annotations.strikethrough then
      value = "~~" .. value .. "~~"
    end
    if annotations.underline then
      value = "<u>" .. value .. "</u>"
    end
  end
  if annotations.color and annotations.color ~= "default" then
    value = string.format("<span class=\"notion-color-%s\">%s</span>", annotations.color, value)
  end
  return value
end

local function sanitize_href(href)
  if href == nil or href == "" or href == vim.NIL then
    return nil
  end
  return href
end

local function rich_text_to_markdown(rich_text)
  local segments = {}
  for _, node in ipairs(rich_text or {}) do
    local text = node.plain_text or node.text and node.text.content or ""
    text = apply_annotations(text, node.annotations)
    local href = sanitize_href(node.href)
    if href then
      text = ("[%s](%s)"):format(text, href)
    end
    table.insert(segments, text)
  end
  return table.concat(segments, "")
end

local function render_children(children, depth)
  local out = {}
  for _, child in ipairs(children or {}) do
    local chunk = M.render_block(child, depth + 1)
    for _, line in ipairs(chunk) do
      table.insert(out, line)
    end
  end
  return out
end

local function pad_blank(out)
  if #out == 0 then
    return
  end
  if out[#out] ~= "" then
    table.insert(out, "")
  end
end

function M.render_block(block, depth)
  depth = depth or 0
  local lines = {}
  local indent = string.rep("  ", depth)
  local block_type = block.type
  local payload = block[block_type] or {}

  if block_type == "paragraph" then
    local text = rich_text_to_markdown(payload.rich_text)
    table.insert(lines, indent .. text)
    pad_blank(lines)
  elseif block_type == "heading_1" then
    table.insert(lines, ("# %s"):format(rich_text_to_markdown(payload.rich_text)))
    pad_blank(lines)
  elseif block_type == "heading_2" then
    table.insert(lines, ("## %s"):format(rich_text_to_markdown(payload.rich_text)))
    pad_blank(lines)
  elseif block_type == "heading_3" then
    table.insert(lines, ("### %s"):format(rich_text_to_markdown(payload.rich_text)))
    pad_blank(lines)
  elseif block_type == "bulleted_list_item" then
    table.insert(lines, indent .. "- " .. rich_text_to_markdown(payload.rich_text))
    for _, line in ipairs(render_children(payload.children, depth + 1)) do
      table.insert(lines, line)
    end
  elseif block_type == "numbered_list_item" then
    table.insert(lines, indent .. "1. " .. rich_text_to_markdown(payload.rich_text))
    for _, line in ipairs(render_children(payload.children, depth + 1)) do
      table.insert(lines, line)
    end
  elseif block_type == "to_do" then
    local mark = payload.checked and "x" or " "
    table.insert(lines, indent .. ("- [%s] %s"):format(mark, rich_text_to_markdown(payload.rich_text)))
    for _, line in ipairs(render_children(payload.children, depth + 1)) do
      table.insert(lines, line)
    end
  elseif block_type == "quote" then
    table.insert(lines, indent .. "> " .. rich_text_to_markdown(payload.rich_text))
    pad_blank(lines)
  elseif block_type == "code" then
    table.insert(lines, ("```%s"):format(payload.language or ""))
    table.insert(lines, rich_text_to_markdown(payload.rich_text))
    table.insert(lines, "```")
    pad_blank(lines)
  elseif block_type == "divider" then
    table.insert(lines, "---")
    pad_blank(lines)
  elseif block_type == "callout" then
    local icon = payload.icon and (payload.icon.emoji or payload.icon.type) or "💡"
    table.insert(lines, indent .. (icon .. " " .. rich_text_to_markdown(payload.rich_text)))
    for _, line in ipairs(render_children(payload.children, depth + 1)) do
      table.insert(lines, line)
    end
  else
    local fallback = ("<!-- unsupported block: %s -->"):format(block_type)
    table.insert(lines, indent .. fallback)
    pad_blank(lines)
  end

  return lines
end

function M.blocks_to_markdown(blocks)
  local lines = {}
  for _, block in ipairs(blocks or {}) do
    local chunk = M.render_block(block, 0)
    for _, line in ipairs(chunk) do
      table.insert(lines, line)
    end
  end
  -- Trim trailing blank lines
  while #lines > 0 and lines[#lines] == "" do
    table.remove(lines, #lines)
  end
  if #lines == 0 then
    lines = { "" }
  end
  return lines
end

function M.extract_title(page, title_property)
  if not page or not page.properties then
    return "Untitled"
  end
  local property = page.properties[title_property]
  if not property or not property.title then
    -- Fallback: search first title property
    for _, value in pairs(page.properties) do
      if value.type == "title" then
        property = value
        break
      end
    end
  end
  local title = rich_text_to_markdown(property and property.title or {})
  if title == "" then
    return "Untitled"
  end
  return title
end

return M
