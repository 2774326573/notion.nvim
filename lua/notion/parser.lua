local M = {}

local languages = require("notion.languages")

local ZERO_WIDTH_SPACE = string.char(226, 128, 139)

local function get_node_text(node, bufnr)
  local text = vim.treesitter.get_node_text(node, bufnr)
  text = text:gsub("\r", "")
  return text
end

local function annotations_defaults()
  return {
    bold = false,
    italic = false,
    strikethrough = false,
    underline = false,
    code = false,
    color = "default",
  }
end

local function build_annotations(overrides)
  local ann = annotations_defaults()
  if overrides then
    for key, value in pairs(overrides) do
      if ann[key] ~= nil then
        ann[key] = value and true or false
      end
    end
  end
  return ann
end

local function make_text_object(text, opts)
  text = text or ""
  opts = opts or {}
  local annotations = build_annotations(opts)
  local link = nil
  local href = nil
  if opts.href and opts.href ~= "" then
    link = { url = opts.href }
    href = opts.href
  end
  return {
    type = "text",
    text = { content = text, link = link },
    plain_text = text,
    annotations = annotations,
    href = href,
  }
end

local function text_object(text)
  return make_text_object(text)
end

local function flush_plain_segment(segments, buffer)
  if #buffer == 0 then
    return
  end
  table.insert(segments, make_text_object(table.concat(buffer)))
  for idx = #buffer, 1, -1 do
    buffer[idx] = nil
  end
end

local function parse_inline_markdown(text)
  if not text or text == "" then
    return {}
  end
  -- Preserve fence markers and horizontal rules as plain text; they are handled elsewhere.
    if text:match("^%s*([`~]{3,}).*$") or text:match("^%s*%-%-%-%s*$") or text:match("^%s*___%s*$") or text:match("^%s*%*%*%*%s*$") then
    return { make_text_object(text) }
  end
  local segments = {}
  local buffer = {}
  local i = 1
  local len = #text
  while i <= len do
    local remaining = len - i + 1
    local trip_star = remaining >= 3 and text:sub(i, i + 2) or nil
    local trip_underscore = remaining >= 3 and text:sub(i, i + 2) or nil
    if trip_star == "***" then
      local closing = text:find("***", i + 3, true)
      if closing then
        flush_plain_segment(segments, buffer)
        local content = text:sub(i + 3, closing - 1)
        table.insert(segments, make_text_object(content, { bold = true, italic = true }))
        i = closing + 3
      else
        table.insert(buffer, text:sub(i, i))
        i = i + 1
      end
    elseif trip_underscore == "___" then
      local closing = text:find("___", i + 3, true)
      if closing then
        flush_plain_segment(segments, buffer)
        local content = text:sub(i + 3, closing - 1)
        table.insert(segments, make_text_object(content, { italic = true, underline = true }))
        i = closing + 3
      else
        table.insert(buffer, text:sub(i, i))
        i = i + 1
      end
    elseif remaining >= 2 and text:sub(i, i + 1) == "**" then
      local closing = text:find("**", i + 2, true)
      if closing then
        flush_plain_segment(segments, buffer)
        local content = text:sub(i + 2, closing - 1)
        table.insert(segments, make_text_object(content, { bold = true }))
        i = closing + 2
      else
        table.insert(buffer, text:sub(i, i))
        i = i + 1
      end
    elseif remaining >= 2 and text:sub(i, i + 1) == "__" then
      local closing = text:find("__", i + 2, true)
      if closing then
        flush_plain_segment(segments, buffer)
        local content = text:sub(i + 2, closing - 1)
        table.insert(segments, make_text_object(content, { underline = true }))
        i = closing + 2
      else
        table.insert(buffer, text:sub(i, i))
        i = i + 1
      end
    elseif remaining >= 2 and text:sub(i, i + 1) == "~~" then
      local closing = text:find("~~", i + 2, true)
      if closing then
        flush_plain_segment(segments, buffer)
        local content = text:sub(i + 2, closing - 1)
        table.insert(segments, make_text_object(content, { strikethrough = true }))
        i = closing + 2
      else
        table.insert(buffer, text:sub(i, i))
        i = i + 1
      end
    else
      local ch = text:sub(i, i)
      if ch == "`" then
        local closing = text:find("`", i + 1, true)
        if closing then
          flush_plain_segment(segments, buffer)
          local content = text:sub(i + 1, closing - 1)
          table.insert(segments, make_text_object(content, { code = true }))
          i = closing + 1
        else
          table.insert(buffer, ch)
          i = i + 1
        end
      elseif ch == "*" then
        local closing = text:find("*", i + 1, true)
        if closing then
          flush_plain_segment(segments, buffer)
          local content = text:sub(i + 1, closing - 1)
          table.insert(segments, make_text_object(content, { italic = true }))
          i = closing + 1
        else
          table.insert(buffer, ch)
          i = i + 1
        end
      elseif ch == "_" then
        local closing = text:find("_", i + 1, true)
        if closing then
          flush_plain_segment(segments, buffer)
          local content = text:sub(i + 1, closing - 1)
          table.insert(segments, make_text_object(content, { italic = true }))
          i = closing + 1
        else
          table.insert(buffer, ch)
          i = i + 1
        end
      elseif ch == "[" then
        local close_bracket = text:find("]", i + 1, true)
        local url = nil
        if close_bracket then
          if text:sub(close_bracket + 1, close_bracket + 1) == "(" then
            local close_paren = text:find(")", close_bracket + 2, true)
            if close_paren then
              url = vim.trim(text:sub(close_bracket + 2, close_paren - 1))
              local label = text:sub(i + 1, close_bracket - 1)
              flush_plain_segment(segments, buffer)
              table.insert(segments, make_text_object(label ~= "" and label or url, { href = url }))
              i = close_paren + 1
            else
              table.insert(buffer, ch)
              i = i + 1
            end
          else
            table.insert(buffer, ch)
            i = i + 1
          end
        else
          table.insert(buffer, ch)
          i = i + 1
        end
      else
        table.insert(buffer, ch)
        i = i + 1
      end
    end
  end
  flush_plain_segment(segments, buffer)
  return segments
end

local function caption_objects(text)
  if not text or text == "" then
    return {}
  end
  return { text_object(text) }
end

local function paragraph_block(text, annotations)
  local rich_text
  if annotations then
    rich_text = { make_text_object(text or "", annotations) }
  else
    rich_text = parse_inline_markdown(text)
    if #rich_text == 0 then
      rich_text = { make_text_object(text or "") }
    end
  end
  return {
    object = "block",
    type = "paragraph",
    paragraph = {
      rich_text = rich_text,
    },
  }
end

local function block_plain_text(block)
  if not block then
    return ""
  end
  local payload = block[block.type]
  if not payload or not payload.rich_text then
    return ""
  end
  local parts = {}
  for _, node in ipairs(payload.rich_text) do
    local value = node.plain_text or (node.text and node.text.content) or ""
    table.insert(parts, value)
  end
  return table.concat(parts, "")
end

local function collapse_markdown_fences(blocks, opts)
  if opts and opts.preserve_code_fences then
    return blocks
  end
  local out = {}
  local i = 1
  while i <= #blocks do
    local block = blocks[i]
    if block.type == "paragraph" then
      local text = block_plain_text(block)
      local opener, info = text:match("^%s*([`~]{3,})(.*)$")
      if opener then
        local fence_char = opener:sub(1, 1)
        local fence_len = #opener
        local language = vim.trim(info or "")
        local body = {}
        local j = i + 1
        local closed = false
        while j <= #blocks do
          local candidate = blocks[j]
          if candidate.type ~= "paragraph" then
            break
          end
          local ctext = block_plain_text(candidate)
          local closing = ctext:match("^%s*([`~]{3,})%s*$")
          if closing and closing:sub(1, 1) == fence_char and #closing >= fence_len then
            closed = true
            j = j + 1
            break
          end
          table.insert(body, ctext)
          j = j + 1
        end
        if closed then
          table.insert(out, code_block(language, table.concat(body, "\n"), opts))
          i = j
          goto continue
        end
      end
    end
    table.insert(out, block)
    i = i + 1
    ::continue::
  end
  return out
end

local function image_block(url, caption)
  if not url or url == "" then
    return paragraph_block("[notion.nvim] image missing url")
  end
  return {
    object = "block",
    type = "image",
    image = {
      type = "external",
      external = { url = url },
      caption = caption_objects(caption),
    },
  }
end

local function heading_block(level, text)
  level = math.max(1, math.min(level, 3))
  local key = ("heading_%d"):format(level)
  local rich_text = parse_inline_markdown(text)
  if #rich_text == 0 then
    rich_text = { make_text_object(text or "") }
  end
  return {
    object = "block",
    type = key,
    [key] = {
      rich_text = rich_text,
    },
  }
end

local function divider_block()
  return { object = "block", type = "divider", divider = vim.empty_dict() }
end

local function code_block(language, text, opts)
  local preserve = opts and opts.preserve_code_fences
  local content = (text or ""):gsub("\r", "")

  if preserve then
    local info = vim.trim(language or "")
    local opener = info ~= "" and ("```%s"):format(info) or "```"
    local chunk = opener
    if content ~= "" then
      chunk = chunk .. "\n" .. content
      if not content:match("\n$") then
        chunk = chunk .. "\n"
      end
    else
      chunk = chunk .. "\n"
    end
    chunk = chunk .. "```"

    local processed_lines = {}
    for _, line in ipairs(vim.split(chunk, "\n", { plain = true, trimempty = false })) do
      if line:match("^%s*[`~]{3,}.*$") then
        table.insert(processed_lines, ZERO_WIDTH_SPACE .. line)
      else
        table.insert(processed_lines, line)
      end
    end
    chunk = table.concat(processed_lines, "\n")

    local rich_text = {}
    local max_length = 2000
    local pos = 1
    while pos <= #chunk do
      local piece = chunk:sub(pos, pos + max_length - 1)
      table.insert(rich_text, make_text_object(piece))
      pos = pos + max_length
    end

    return {
      object = "block",
      type = "paragraph",
      paragraph = {
        rich_text = rich_text,
      },
    }
  end

  local normalized_language = languages.normalize(language and vim.trim(language) or language)

  local rich_text = {}
  local max_length = 2000
  local pos = 1

  if content == "" then
    table.insert(rich_text, make_text_object("", { code = true }))
  else
    while pos <= #content do
      local piece = content:sub(pos, pos + max_length - 1)
      table.insert(rich_text, make_text_object(piece, { code = true }))
      pos = pos + max_length
    end
  end

  return {
    object = "block",
    type = "code",
    code = {
      language = normalized_language,
      rich_text = rich_text,
    },
  }
end

local function quote_block(text)
  local rich_text = parse_inline_markdown(text)
  if #rich_text == 0 then
    rich_text = { make_text_object(text or "") }
  end
  return {
    object = "block",
    type = "quote",
    quote = {
      rich_text = rich_text,
    },
  }
end

local function list_block(block_type, text, children, opts)
  local rich_text = parse_inline_markdown(text)
  if #rich_text == 0 then
    rich_text = { make_text_object(text or "") }
  end
  local block = {
    object = "block",
    type = block_type,
    [block_type] = {
      rich_text = rich_text,
    },
  }
  if block_type == "to_do" then
    block.to_do.checked = opts and opts.checked or false
  end
  if children and #children > 0 then
    block[block_type].children = children
  end
  return block
end

local parse_node, parse_list, parse_list_item

local function parse_image_markdown(text)
  if not text then
    return nil
  end
  local alt, target = text:match("^!%[(.-)%]%((.*)%)$")
  if not alt then
    return nil
  end
  target = vim.trim(target)
  if target == "" then
    return nil
  end
  local title
  local url = target
  local quoted_url, quoted_title = target:match('^<?([^%s>]+)>?%s+"(.-)"%s*$')
  if quoted_url then
    url = quoted_url
    title = quoted_title
  end
  if url:sub(1, 1) == "<" and url:sub(-1) == ">" then
    url = url:sub(2, -2)
  end
  url = vim.trim(url)
  if url == "" then
    return nil
  end
  return {
    alt = vim.trim(alt),
    url = url,
    title = title and vim.trim(title) or nil,
  }
end

local function extract_fenced_code(text)
  if not text or text == "" then
    return nil
  end
  local lines = vim.split(text, "\n", { plain = true })
  if #lines < 3 then
    return nil
  end
    local opener, info = lines[1]:match("^%s*([`~]{3,})(.*)$")
  if not opener then
    return nil
  end
  local fence_char = opener:sub(1, 1)
  local fence_len = #opener
  local closing_idx
  for idx = #lines, 2, -1 do
    local closing = lines[idx]:match("^%s*([`~]{3,})%s*$")
    if closing then
      if closing:sub(1, 1) == fence_char and #closing >= fence_len then
        closing_idx = idx
        break
      end
    elseif lines[idx]:match("%S") then
      return nil
    end
  end
  if not closing_idx or closing_idx <= 2 then
    return nil
  end
  for idx = closing_idx + 1, #lines do
    if lines[idx]:match("%S") then
      return nil
    end
  end
  local body = {}
  for idx = 2, closing_idx - 1 do
    table.insert(body, lines[idx])
  end
  local content = table.concat(body, "\n")
  return {
    language = vim.trim(info or ""),
    content = content,
  }
end
local function fallback_blocks(bufnr, opts)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local blocks = {}
  local chunk = {}

  local function flush_paragraph()
    if #chunk == 0 then
      return
    end
    local text = table.concat(chunk, "\n")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text ~= "" then
      table.insert(blocks, paragraph_block(text))
    end
    chunk = {}
  end

  local function push_heading(line)
    local hashes, content = line:match("^(#+)%s*(.-)%s*$")
    if not hashes then
      return false
    end
    flush_paragraph()
    local level = math.min(#hashes, 3)
    content = content ~= "" and content or "Untitled"
    table.insert(blocks, heading_block(level, content))
    return true
  end

  local function push_simple_list(line)
    local todo_mark, todo_text = line:match("^%s*[-*+]%s*%[(%u?%l?)%]%s*(.*)$")
    if todo_mark then
      flush_paragraph()
      local checked = todo_mark == "x" or todo_mark == "X"
      todo_text = todo_text ~= "" and todo_text or " "
      table.insert(blocks, list_block("to_do", todo_text, nil, { checked = checked }))
      return true
    end

    local bullet_text = line:match("^%s*[-*+]%s+(.*)$")
    if bullet_text then
      flush_paragraph()
      bullet_text = bullet_text ~= "" and bullet_text or " "
      table.insert(blocks, list_block("bulleted_list_item", bullet_text))
      return true
    end

    local number_text = line:match("^%s*%d+[%.%)]%s+(.*)$")
    if number_text then
      flush_paragraph()
      number_text = number_text ~= "" and number_text or " "
      table.insert(blocks, list_block("numbered_list_item", number_text))
      return true
    end

    return false
  end

  local function push_quote(line)
    local content = line:match("^%s*>%s?(.*)$")
    if not content then
      return false
    end
    flush_paragraph()
    content = content ~= "" and content or " "
    table.insert(blocks, quote_block(content))
    return true
  end

  local function push_divider(line)
    if line:match("^%s*[-*_][-%*_ ]*[-*_]%s*$") then
      flush_paragraph()
      table.insert(blocks, divider_block())
      return true
    end
    return false
  end

  local function push_image(line)
    local parsed = parse_image_markdown(vim.trim(line))
    if not parsed then
      return false
    end
    flush_paragraph()
    local caption = parsed.alt ~= "" and parsed.alt or (parsed.title or "")
    table.insert(blocks, image_block(parsed.url, caption))
    return true
  end

  local in_code_block = false
  local code_fence = nil
  local code_language = ""
  local code_lines = {}

  local function finish_code_block()
    if not in_code_block then
      return
    end
    table.insert(blocks, code_block(code_language, table.concat(code_lines, "\n"), opts))
    in_code_block = false
    code_fence = nil
    code_language = ""
    code_lines = {}
  end

  for _, line in ipairs(lines) do
    if in_code_block then
      local closing = line:match("^%s*([`~]{3,})%s*$")
      if closing and code_fence and closing:sub(1, 1) == code_fence then
        finish_code_block()
      else
        table.insert(code_lines, line)
      end
    else
      local fence, info = line:match("^%s*([`~]{3,})(.*)$")
      if fence then
        flush_paragraph()
        in_code_block = true
        code_fence = fence:sub(1, 1)
        code_language = vim.trim(info or "")
        code_lines = {}
      elseif line:match("^%s*$") then
        flush_paragraph()
      else
        if not (push_heading(line) or push_simple_list(line) or push_quote(line) or push_divider(line) or push_image(line)) then
          table.insert(chunk, line)
        end
      end
    end
  end
  flush_paragraph()
  finish_code_block()

  if #blocks == 0 then
    for _, line in ipairs(lines) do
      if line:match("%S") then
        table.insert(blocks, paragraph_block(line))
      end
    end
  end

  return blocks
end

parse_list = function(node, bufnr, opts)
  local items = {}
  for i = 0, node:named_child_count() - 1 do
    local child = node:named_child(i)
    if child:type() == "list_item" then
      local block = parse_list_item(child, bufnr, opts)
      if block then
        table.insert(items, block)
      end
    end
  end
  return items
end

parse_list_item = function(node, bufnr, opts)
  local marker = node:child(0)
  local marker_type = marker and marker:type() or ""

  local block_type = "bulleted_list_item"
  local checked = false

  if marker_type == "list_marker_dot" or marker_type == "list_marker_parenthesis" then
    block_type = "numbered_list_item"
  elseif marker_type == "task_list_marker_checked" then
    block_type = "to_do"
    checked = true
  elseif marker_type == "task_list_marker_unchecked" then
    block_type = "to_do"
    checked = false
  end

  local text = ""
  local children = {}

  for i = 0, node:named_child_count() - 1 do
    local child = node:named_child(i)
    local ctype = child:type()
    if ctype == "paragraph" then
      text = get_node_text(child, bufnr):gsub("\n", " ")
    elseif ctype == "list" then
      children = parse_list(child, bufnr, opts)
    end
  end

  return list_block(block_type, text, children, { checked = checked })
end

local function parse_children(blocks, node, bufnr, opts)
  for i = 0, node:named_child_count() - 1 do
    local child = node:named_child(i)
    local block = parse_node(child, bufnr, opts)
    if block then
      if vim.tbl_islist(block) then
        for _, nested in ipairs(block) do
          table.insert(blocks, nested)
        end
      else
        table.insert(blocks, block)
      end
    end
  end
end

parse_node = function(node, bufnr, opts)
  local ntype = node:type()

  if ntype == "paragraph" then
    local text = get_node_text(node, bufnr)
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then
      return nil
    end
    local parsed_image = parse_image_markdown(text)
    if parsed_image then
      local caption = parsed_image.alt ~= "" and parsed_image.alt or (parsed_image.title or "")
      return image_block(parsed_image.url, caption)
    end
    local fenced = extract_fenced_code(text)
    if fenced then
      return code_block(fenced.language, fenced.content, opts)
    end
    return paragraph_block(text)
  elseif ntype == "atx_heading" then
    local raw = get_node_text(node, bufnr)
    local hashes, content = raw:match("^(#+)%s*(.-)%s*$")
    hashes = hashes or ""
    content = content or raw
    return heading_block(#hashes, content)
  elseif ntype == "fenced_code_block" then
    local language = ""
    local text = ""
    for i = 0, node:named_child_count() - 1 do
      local child = node:named_child(i)
      if child:type() == "info_string" then
        language = vim.trim(get_node_text(child, bufnr))
      elseif child:type() == "code_fence_content" then
        text = get_node_text(child, bufnr)
      end
    end
    return code_block(language, text, opts)
  elseif ntype == "indented_code_block" then
    local text = get_node_text(node, bufnr)
    return code_block("plain text", text, opts)
  elseif ntype == "block_quote" then
    local raw = get_node_text(node, bufnr)
    local lines = {}
    for line in raw:gmatch("[^\n]+") do
      line = line:gsub("^>%s*", "")
      table.insert(lines, line)
    end
    return quote_block(table.concat(lines, "\n"))
  elseif ntype == "thematic_break" then
    return divider_block()
  elseif ntype == "list" then
    return parse_list(node, bufnr, opts)
  elseif ntype == "empty" then
    return nil
  elseif ntype == "html_block" then
    local text = get_node_text(node, bufnr)
    return paragraph_block(text)
  end

  return nil
end

local function analyze_code_blocks(blocks, opts)
  local total = 0
  local with_fences = 0

  local function chunk_contains_fence(text)
    if not text or text == "" then
      return false
    end
    if opts and opts.preserve_code_fences then
      text = text:gsub(ZERO_WIDTH_SPACE, "")
    end
    for line in text:gmatch("[^\n]+") do
      if line:match("^%s*[`~]{3,}.*$") then
        return true
      end
    end
    return false
  end

  local function block_has_raw_fence(block)
    local payload = block.code
    if not payload then
      return false
    end
    for _, rt in ipairs(payload.rich_text or {}) do
      local value = (rt.text and rt.text.content) or rt.plain_text or ""
      if chunk_contains_fence(value) then
        return true
      end
    end
    return false
  end

  local function walk(list)
    for _, block in ipairs(list or {}) do
      if block.type == "code" then
        total = total + 1
        if block_has_raw_fence(block) then
          with_fences = with_fences + 1
        end
      elseif block.type == "paragraph" then
        local text = block_plain_text(block)
        if opts and opts.preserve_code_fences then
          text = text:gsub(ZERO_WIDTH_SPACE, "")
        end
        if text:match("^%s*([`~]{3,}).*") then
          total = total + 1
        end
      end
      local payload = block[block.type]
      if payload and payload.children then
        walk(payload.children)
      end
    end
  end

  walk(blocks)
  return total, with_fences
end

local function count_fenced_code_in_buffer(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local expected = 0
  local in_fence = false
  local fence_char = nil
  for _, line in ipairs(lines) do
    if in_fence then
      local closing = line:match("^%s*([`~]{3,})%s*$")
      if closing and fence_char and closing:sub(1, 1) == fence_char then
        in_fence = false
        fence_char = nil
      end
    else
      local fence = line:match("^%s*([`~]{3,})(.*)$")
      if fence then
        expected = expected + 1
        in_fence = true
        fence_char = fence:sub(1, 1)
      end
    end
  end
  return expected
end

function M.buffer_to_blocks(bufnr, language, opts)
  language = language or "markdown"
  local ok, parser_or_err = pcall(vim.treesitter.get_parser, bufnr, language)
  if not ok then
    vim.schedule(function()
      vim.notify("[notion.nvim] Failed to load tree-sitter parser: " .. parser_or_err, vim.log.levels.ERROR)
    end)
    return {}
  end
  local parser = parser_or_err
  local trees = parser:parse()
  local tree = trees and trees[1]
  if not tree then
    return {}
  end
  local root = tree:root()

  local blocks = {}
  parse_children(blocks, root, bufnr, opts)
  blocks = collapse_markdown_fences(blocks, opts)
  local expected_code_blocks = count_fenced_code_in_buffer(bufnr)
  local actual_code_blocks, fencey_code_blocks = analyze_code_blocks(blocks, opts)
  -- Fall back when tree-sitter fails to emit code blocks, otherwise Notion sees raw fences.
  if #blocks == 0
    or (expected_code_blocks > 0 and (actual_code_blocks < expected_code_blocks or fencey_code_blocks > 0))
  then
    blocks = fallback_blocks(bufnr, opts)
    blocks = collapse_markdown_fences(blocks, opts)
  end
  return blocks
end

return M
