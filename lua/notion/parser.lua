local M = {}

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
        if key == "color" then
          ann[key] = value or "default"
        else
          ann[key] = value and true or false
        end
      end
    end
  end
  return ann
end

local notion_text_colors = {
  default = true,
  gray = true,
  brown = true,
  orange = true,
  yellow = true,
  green = true,
  blue = true,
  purple = true,
  pink = true,
  red = true,
}

local function normalize_color_input(value)
  return (value or ""):lower():gsub("[%s%-]+", "_")
end

local function is_valid_text_color(color)
  return color ~= nil and notion_text_colors[color] == true
end

local function is_valid_background_color(color)
  if not color then
    return false
  end
  if color == "default" then
    return true
  end
  if not color:match("_background$") then
    return false
  end
  local base = color:gsub("_background$", "")
  return is_valid_text_color(base)
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

local function text_object(text, opts)
  return make_text_object(text, opts)
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

local function equation_rich_text(expression)
  local expr = expression or ""
  return {
    type = "equation",
    equation = { expression = expr },
    plain_text = expr,
    annotations = annotations_defaults(),
    href = nil,
  }
end

local function find_unescaped_marker(text, marker, start_pos)
  local pos = start_pos
  local marker_len = #marker
  while true do
    local idx = text:find(marker, pos, true)
    if not idx then
      return nil
    end
    if idx == start_pos then
      pos = idx + marker_len
    elseif text:sub(idx - 1, idx - 1) ~= "\\" then
      return idx
    else
      pos = idx + marker_len
    end
  end
end

local function parse_highlight_markup(raw)
  if not raw then
    return nil
  end
  local body = raw
  local color = "yellow_background"
  local cstart, cend, explicit = body:find("^%{%s*([^%}]+)%s*%}")
  if cstart then
    color = normalize_color_input(explicit)
    body = body:sub(cend + 1)
  end
  body = vim.trim(body)
  if body == "" then
    return nil
  end
  if color == "" then
    color = "yellow_background"
  end
  if not color:match("_background$") then
    color = color .. "_background"
  end
  if not is_valid_background_color(color) then
    return nil
  end
  return body, color
end

local function parse_color_markup(raw)
  if not raw then
    return nil
  end
  local color_token, rest = raw:match("^%{%s*([^%}]+)%s*%}(.*)$")
  if not color_token then
    return nil
  end
  local color = normalize_color_input(color_token)
  if not is_valid_text_color(color) then
    return nil
  end
  rest = vim.trim(rest or "")
  if rest == "" then
    return nil
  end
  return rest, color
end

local function parse_inline_markdown(text)
  if not text or text == "" then
    return {}
  end
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
    elseif remaining >= 2 and text:sub(i, i + 1) == "==" then
      local closing = text:find("==", i + 2, true)
      if closing then
        local content = text:sub(i + 2, closing - 1)
        local inner, highlight_color = parse_highlight_markup(content)
        if inner then
          flush_plain_segment(segments, buffer)
          table.insert(segments, make_text_object(inner, { color = highlight_color }))
          i = closing + 2
        else
          table.insert(buffer, text:sub(i, closing + 1))
          i = closing + 2
        end
      else
        table.insert(buffer, text:sub(i, i))
        i = i + 1
      end
    elseif remaining >= 2 and text:sub(i, i + 1) == "::" then
      local closing = text:find("::", i + 2, true)
      if closing then
        local content = text:sub(i + 2, closing - 1)
        local inner, color = parse_color_markup(content)
        if inner then
          flush_plain_segment(segments, buffer)
          table.insert(segments, make_text_object(inner, { color = color }))
          i = closing + 2
        else
          table.insert(buffer, text:sub(i, closing + 1))
          i = closing + 2
        end
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
      elseif ch == "$" then
        local double = text:sub(i, i + 1) == "$$"
        if double then
          local closing = find_unescaped_marker(text, "$$", i + 2)
          if closing then
            flush_plain_segment(segments, buffer)
            local content = text:sub(i + 2, closing - 1)
            table.insert(segments, equation_rich_text(vim.trim(content)))
            i = closing + 2
          else
            table.insert(buffer, ch)
            i = i + 1
          end
        else
          local closing = find_unescaped_marker(text, "$", i + 1)
          if closing then
            flush_plain_segment(segments, buffer)
            local content = text:sub(i + 1, closing - 1)
            table.insert(segments, equation_rich_text(vim.trim(content)))
            i = closing + 1
          else
            table.insert(buffer, ch)
            i = i + 1
          end
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
  local parsed = parse_inline_markdown(text)
  if #parsed == 0 then
    parsed = { make_text_object(text) }
  end
  return parsed
end

local notion_languages = {
  ["abap"] = true,
  ["agda"] = true,
  ["arduino"] = true,
  ["ascii art"] = true,
  ["bash"] = true,
  ["basic"] = true,
  ["bnf"] = true,
  ["c"] = true,
  ["csharp"] = true,
  ["cpp"] = true,
  ["clojure"] = true,
  ["coffeescript"] = true,
  ["csp"] = true,
  ["css"] = true,
  ["dart"] = true,
  ["dhall"] = true,
  ["diff"] = true,
  ["docker"] = true,
  ["elixir"] = true,
  ["elm"] = true,
  ["erlang"] = true,
  ["flow"] = true,
  ["fortran"] = true,
  ["fsharp"] = true,
  ["gherkin"] = true,
  ["glsl"] = true,
  ["go"] = true,
  ["graphql"] = true,
  ["groovy"] = true,
  ["haskell"] = true,
  ["html"] = true,
  ["java"] = true,
  ["javascript"] = true,
  ["json"] = true,
  ["julia"] = true,
  ["kotlin"] = true,
  ["latex"] = true,
  ["less"] = true,
  ["lisp"] = true,
  ["livescript"] = true,
  ["llvm ir"] = true,
  ["lua"] = true,
  ["makefile"] = true,
  ["markdown"] = true,
  ["markup"] = true,
  ["mathematica"] = true,
  ["matlab"] = true,
  ["mermaid"] = true,
  ["flowchart"] = true,
  ["nginx"] = true,
  ["nim"] = true,
  ["nix"] = true,
  ["notion"] = true,
  ["objective-c"] = true,
  ["ocaml"] = true,
  ["pascal"] = true,
  ["perl"] = true,
  ["php"] = true,
  ["plain text"] = true,
  ["powershell"] = true,
  ["prolog"] = true,
  ["protobuf"] = true,
  ["python"] = true,
  ["r"] = true,
  ["reason"] = true,
  ["ruby"] = true,
  ["rust"] = true,
  ["sass"] = true,
  ["scala"] = true,
  ["scheme"] = true,
  ["scss"] = true,
  ["shell"] = true,
  ["solidity"] = true,
  ["sql"] = true,
  ["swift"] = true,
  ["typescript"] = true,
  ["vb"] = true,
  ["verilog"] = true,
  ["vhdl"] = true,
  ["visual basic"] = true,
  ["webassembly"] = true,
  ["xml"] = true,
  ["yaml"] = true,
}

local language_aliases = {
  ["c++"] = "cpp",
  ["cplusplus"] = "cpp",
  ["cxx"] = "cpp",
  ["c#"] = "csharp",
  ["cs"] = "csharp",
  ["f#"] = "fsharp",
  ["fs"] = "fsharp",
  ["objective c"] = "objective-c",
  ["objectivec"] = "objective-c",
  ["objc"] = "objective-c",
  ["js"] = "javascript",
  ["node"] = "javascript",
  ["ts"] = "typescript",
  ["py"] = "python",
  ["ps1"] = "powershell",
  ["powershell"] = "powershell",
  ["sh"] = "shell",
  ["zsh"] = "shell",
  ["bash"] = "bash",
  ["shell"] = "shell",
  ["plaintext"] = "plain text",
  ["text"] = "plain text",
  ["plain"] = "plain text",
  ["c++ "] = "cpp",
  ["ascii-art"] = "ascii art",
  ["ascii"] = "ascii art",
  ["llvm"] = "llvm ir",
  ["llvm-ir"] = "llvm ir",
  ["notion formula"] = "notion",
  ["notion 函数"] = "notion",
  ["notion函数"] = "notion",
  ["wolfram"] = "mathematica",
  ["wolfram language"] = "mathematica",
  ["flowchart"] = "mermaid",
  ["flow chart"] = "mermaid",
}

local function normalize_language(language)
  if not language or language == "" then
    return "plain text"
  end
  local lang = language:lower()
  lang = lang:gsub("[_%s]+", " ")
  lang = lang:gsub("^%s+", ""):gsub("%s+$", "")
  lang = language_aliases[lang] or lang
  if notion_languages[lang] then
    return lang
  end
  -- try replacing spaces with hyphen (objective c -> objective-c)
  local hyphenated = lang:gsub("%s+", "-")
  hyphenated = language_aliases[hyphenated] or hyphenated
  if notion_languages[hyphenated] then
    return hyphenated
  end
  return "plain text"
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

local function collapse_markdown_fences(blocks)
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
          table.insert(out, code_block(language, table.concat(body, "\n")))
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

local function image_block(url, caption, raw)
  if not url or url == "" then
    return paragraph_block(raw or "[notion.nvim] image missing url")
  end
  if #url > 2000 then
    return paragraph_block(raw or "[notion.nvim] image url exceeds 2000 characters")
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

local function code_block(language, text)
  -- Notion API has a 2000 character limit per rich_text item
  -- Split long code into multiple text objects
  local function sanitize_code_content(value)
    local cleaned = (value or ""):gsub("\r", "")
    if cleaned == "" then
      return cleaned
    end
    local lines = vim.split(cleaned, "\n", { plain = true })
    if #lines == 0 then
      return cleaned
    end
    while #lines > 0 and lines[#lines] == "" do
      table.remove(lines, #lines)
    end
    while #lines > 0 and lines[1] == "" do
      table.remove(lines, 1)
    end
    local last = lines[#lines]
    local closing = last and last:match("^%s*([`~]{3,})%s*$")
    if closing then
      local fence_char = closing:sub(1, 1)
      local fence_seq = string.rep(fence_char, #closing)
      local first = lines[1]
      if first and first:match("^%s*" .. fence_seq) then
        table.remove(lines, #lines)
        table.remove(lines, 1)
        while #lines > 0 and lines[1] == "" do
          table.remove(lines, 1)
        end
        while #lines > 0 and lines[#lines] == "" do
          table.remove(lines, #lines)
        end
      end
    end
    return table.concat(lines, "\n")
  end

  local clean_text = sanitize_code_content(text)

  local rich_text = {}
  local max_length = 2000

  if #clean_text <= max_length then
    table.insert(rich_text, make_text_object(clean_text, { code = true }))
  else
    local pos = 1
    while pos <= #clean_text do
      local chunk = clean_text:sub(pos, pos + max_length - 1)
      table.insert(rich_text, make_text_object(chunk, { code = true }))
      pos = pos + max_length
    end
  end

  return {
    object = "block",
    type = "code",
    code = {
      rich_text = rich_text,
      language = normalize_language(language),
    },
  }
end

local function quote_block(text, opts)
  opts = opts or {}
  local rich_text = opts.rich_text
  if not rich_text then
    rich_text = parse_inline_markdown(text)
    if #rich_text == 0 then
      rich_text = { make_text_object(text or "") }
    end
  end
  local block = {
    object = "block",
    type = "quote",
    quote = {
      rich_text = rich_text,
    },
  }
  if opts.children and #opts.children > 0 then
    block.quote.children = opts.children
  end
  return block
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

local function equation_block(expression)
  return {
    object = "block",
    type = "equation",
    equation = {
      expression = expression or "",
    },
  }
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

local function extract_display_math(text)
  if not text or text == "" then
    return nil
  end
  local trimmed = vim.trim(text)
  if not trimmed:match("^%$%$") then
    return nil
  end
  if trimmed:sub(-2) == "$$" and #trimmed > 4 then
    local inner = trimmed:sub(3, -3)
    return vim.trim(inner)
  end
  local lines = vim.split(text, "\n", { plain = true })
  if #lines >= 2 and lines[1]:match("^%s*%$%$%s*$") then
    for idx = 2, #lines do
      if lines[idx]:match("^%s*%$%$%s*$") then
        local body = {}
        for j = 2, idx - 1 do
          table.insert(body, lines[j])
        end
        return vim.trim(table.concat(body, "\n"))
      end
    end
  end
  return nil
end
local function fallback_blocks(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local blocks = {}
  local chunk = {}
  local list_stack = {}

  local function clear_list_stack()
    list_stack = {}
  end

  local function attach_list_block(block, indent)
    while #list_stack > 0 and indent <= list_stack[#list_stack].indent do
      table.remove(list_stack)
    end
    local parent = list_stack[#list_stack]
    if parent then
      local payload = parent.block[parent.block.type]
      payload.children = payload.children or {}
      table.insert(payload.children, block)
    else
      table.insert(blocks, block)
    end
    table.insert(list_stack, { indent = indent, block = block })
  end

  local function indent_width(prefix)
    if prefix:find("\t") then
      prefix = prefix:gsub("\t", "    ")
    end
    return #prefix
  end

  local function flush_paragraph(clear_lists)
    if #chunk == 0 then
      return
    end
    local text = table.concat(chunk, "\n")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text ~= "" then
      local bold = text:match("^%*%*(.+)%*%*$") or text:match("^__(.+)__$")
      if bold then
        table.insert(blocks, paragraph_block(bold, { bold = true }))
      else
        local italic = text:match("^%*(.+)%*$") or text:match("^_(.+)_$")
        if italic then
          table.insert(blocks, paragraph_block(italic, { italic = true }))
        else
          local strike = text:match("^~~(.+)~~$")
          if strike then
            table.insert(blocks, paragraph_block(strike, { strikethrough = true }))
          else
            local highlight_raw = text:match("^==(.+)==$")
            if highlight_raw then
              local highlight_text, highlight_color = parse_highlight_markup(highlight_raw)
              if highlight_text then
                table.insert(blocks, paragraph_block(highlight_text, { color = highlight_color }))
              else
                table.insert(blocks, paragraph_block(text))
              end
            else
              local color_raw = text:match("^::(.+)::$")
              if color_raw then
                local color_text, color_name = parse_color_markup(color_raw)
                if color_text then
                  table.insert(blocks, paragraph_block(color_text, { color = color_name }))
                else
                  table.insert(blocks, paragraph_block(text))
                end
              else
                local inline_code = text:match("^`(.+)`$")
                if inline_code then
                  table.insert(blocks, paragraph_block(inline_code, { code = true }))
                else
                  table.insert(blocks, paragraph_block(text))
                end
              end
            end
          end
        end
      end
    end
    chunk = {}
    if clear_lists ~= false then
      clear_list_stack()
    end
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
    clear_list_stack()
    return true
  end

  local function push_simple_list(line)
    local todo_ws, todo_mark, todo_text = line:match("^(%s*)[-*+]%s*%[([xX%s])%]%s*(.*)$")
    if todo_ws then
      flush_paragraph(false)
      local indent = indent_width(todo_ws)
      local checked = todo_mark == "x" or todo_mark == "X"
      todo_text = todo_text ~= "" and todo_text or " "
      local block = list_block("to_do", todo_text, nil, { checked = checked })
      attach_list_block(block, indent)
      return true
    end

    local bullet_ws, bullet_text = line:match("^(%s*)[-*+]%s+(.*)$")
    if bullet_ws then
      flush_paragraph(false)
      local indent = indent_width(bullet_ws)
      bullet_text = bullet_text ~= "" and bullet_text or " "
      local block = list_block("bulleted_list_item", bullet_text)
      attach_list_block(block, indent)
      return true
    end

    local number_ws, number_text = line:match("^(%s*)%d+[%.%)]%s+(.*)$")
    if number_ws then
      flush_paragraph(false)
      local indent = indent_width(number_ws)
      number_text = number_text ~= "" and number_text or " "
      local block = list_block("numbered_list_item", number_text)
      attach_list_block(block, indent)
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
    clear_list_stack()
    return true
  end

  local function push_divider(line)
    if line:match("^%s*[-*_][-%*_ ]*[-*_]%s*$") then
      flush_paragraph()
      table.insert(blocks, divider_block())
      clear_list_stack()
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
    table.insert(blocks, image_block(parsed.url, caption, line))
    clear_list_stack()
    return true
  end

  local in_code_block = false
  local code_fence = nil
  local code_language = ""
  local code_lines = {}
  local in_equation_block = false
  local equation_lines = {}

  local function finish_code_block()
    if not in_code_block then
      return
    end
    table.insert(blocks, code_block(code_language, table.concat(code_lines, "\n")))
    in_code_block = false
    code_fence = nil
    code_language = ""
    code_lines = {}
    clear_list_stack()
  end

  local function finish_equation_block()
    if not in_equation_block then
      return
    end
    table.insert(blocks, equation_block(vim.trim(table.concat(equation_lines, "\n"))))
    in_equation_block = false
    equation_lines = {}
    clear_list_stack()
  end

  for _, line in ipairs(lines) do
    if in_code_block then
      local closing = line:match("^%s*([`~]{3,})%s*$")
      if closing and code_fence and closing:sub(1, 1) == code_fence then
        finish_code_block()
      else
        table.insert(code_lines, line)
      end
    elseif in_equation_block then
      if line:match("^%s*%$%$%s*$") then
        finish_equation_block()
      else
        table.insert(equation_lines, line)
      end
    else
      local fence, info = line:match("^%s*([`~]{3,})(.*)$")
      if fence then
        flush_paragraph()
        in_code_block = true
        code_fence = fence:sub(1, 1)
        code_language = vim.trim(info or "")
        code_lines = {}
      elseif line:match("^%s*%$%$%s*$") then
        flush_paragraph()
        finish_equation_block()
        in_equation_block = true
        equation_lines = {}
      elseif line:match("^%s*%$%$(.+)%$%$%s*$") then
        flush_paragraph()
        local expr = line:match("^%s*%$%$(.+)%$%$%s*$")
        table.insert(blocks, equation_block(vim.trim(expr or "")))
        clear_list_stack()
      elseif line:match("^%s*$") then
        flush_paragraph()
        clear_list_stack()
      else
        if not (push_heading(line) or push_simple_list(line) or push_quote(line) or push_divider(line) or push_image(line)) then
          if #list_stack > 0 then
            clear_list_stack()
          end
          table.insert(chunk, line)
        end
      end
    end
  end
  flush_paragraph()
  finish_code_block()
  finish_equation_block()

  if #blocks == 0 then
    for _, line in ipairs(lines) do
      if line:match("%S") then
        table.insert(blocks, paragraph_block(line))
      end
    end
  end

  return blocks
end

parse_list = function(node, bufnr)
  local items = {}
  for i = 0, node:named_child_count() - 1 do
    local child = node:named_child(i)
    if child:type() == "list_item" then
      local block = parse_list_item(child, bufnr)
      if block then
        table.insert(items, block)
      end
    end
  end
  return items
end

parse_list_item = function(node, bufnr)
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
      children = parse_list(child, bufnr)
    end
  end

  return list_block(block_type, text, children, { checked = checked })
end

local function parse_children(blocks, node, bufnr)
  for i = 0, node:named_child_count() - 1 do
    local child = node:named_child(i)
    local block = parse_node(child, bufnr)
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

parse_node = function(node, bufnr)
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
      return image_block(parsed_image.url, caption, text)
    end
    local display_math = extract_display_math(text)
    if display_math then
      return equation_block(display_math)
    end
    local fenced = extract_fenced_code(text)
    if fenced then
      return code_block(fenced.language, fenced.content)
    end
    local bold = text:match("^%*%*(.+)%*%*$") or text:match("^__(.+)__$")
    if bold then
      return paragraph_block(bold, { bold = true })
    end
    local italic = text:match("^%*(.+)%*$") or text:match("^_(.+)_$")
    if italic then
      return paragraph_block(italic, { italic = true })
    end
    local strike = text:match("^~~(.+)~~$")
    if strike then
      return paragraph_block(strike, { strikethrough = true })
    end
    local highlight_raw = text:match("^==(.+)==$")
    if highlight_raw then
      local highlight_text, highlight_color = parse_highlight_markup(highlight_raw)
      if highlight_text then
        return paragraph_block(highlight_text, { color = highlight_color })
      end
    end
    local color_raw = text:match("^::(.+)::$")
    if color_raw then
      local color_text, color_name = parse_color_markup(color_raw)
      if color_text then
        return paragraph_block(color_text, { color = color_name })
      end
    end
    local inline_code = text:match("^`(.+)`$")
    if inline_code then
      return paragraph_block(inline_code, { code = true })
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
    return code_block(language, text)
  elseif ntype == "indented_code_block" then
    local text = get_node_text(node, bufnr)
    return code_block("plain text", text)
  elseif ntype == "block_quote" then
    local rich_text = {}
    local quote_children = {}
    local last_paragraph = false

    for i = 0, node:named_child_count() - 1 do
      local child = node:named_child(i)
      local ctype = child:type()
      if ctype == "paragraph" then
        local text = get_node_text(child, bufnr)
        text = text:gsub("^%s+", ""):gsub("%s+$", "")
        local parsed = parse_inline_markdown(text)
        if #parsed == 0 then
          parsed = { make_text_object(text) }
        end
        if #rich_text > 0 then
          table.insert(rich_text, make_text_object("\n"))
        end
        for _, rt in ipairs(parsed) do
          table.insert(rich_text, rt)
        end
        last_paragraph = true
      elseif ctype == "list" then
        local items = parse_list(child, bufnr)
        for _, item in ipairs(items) do
          table.insert(quote_children, item)
        end
        last_paragraph = false
      else
        local block = parse_node(child, bufnr)
        if block then
          if vim.tbl_islist(block) then
            for _, nested in ipairs(block) do
              table.insert(quote_children, nested)
            end
          else
            table.insert(quote_children, block)
          end
        end
        last_paragraph = false
      end
    end

    if #rich_text == 0 then
      rich_text = { make_text_object("") }
    elseif last_paragraph and rich_text[#rich_text].plain_text == "\n" then
      table.remove(rich_text, #rich_text)
    end

    return quote_block(nil, { rich_text = rich_text, children = quote_children })
  elseif ntype == "thematic_break" then
    return divider_block()
  elseif ntype == "list" then
    return parse_list(node, bufnr)
  elseif ntype == "empty" then
    return nil
  elseif ntype == "html_block" then
    local text = get_node_text(node, bufnr)
    return paragraph_block(text)
  end

  return nil
end

local function analyze_code_blocks(blocks)
  local total = 0
  local with_fences = 0

  local function chunk_contains_fence(text)
    if not text or text == "" then
      return false
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

function M.buffer_to_blocks(bufnr, language)
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
  parse_children(blocks, root, bufnr)
  blocks = collapse_markdown_fences(blocks)
  local expected_code_blocks = count_fenced_code_in_buffer(bufnr)
  local actual_code_blocks, fencey_code_blocks = analyze_code_blocks(blocks)
  -- Fall back when tree-sitter fails to emit code blocks, otherwise Notion sees raw fences.
  if #blocks == 0
    or (expected_code_blocks > 0 and (actual_code_blocks < expected_code_blocks or fencey_code_blocks > 0))
  then
    blocks = fallback_blocks(bufnr)
    blocks = collapse_markdown_fences(blocks)
  end
  return blocks
end

return M
