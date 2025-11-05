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

local function text_object(text)
  return {
    type = "text",
    text = { content = text },
    annotations = annotations_defaults(),
  }
end

local notion_languages = {
  ["abap"] = true,
  ["arduino"] = true,
  ["bash"] = true,
  ["basic"] = true,
  ["c"] = true,
  ["csharp"] = true,
  ["cpp"] = true,
  ["clojure"] = true,
  ["coffeescript"] = true,
  ["csp"] = true,
  ["css"] = true,
  ["dart"] = true,
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
  ["lua"] = true,
  ["makefile"] = true,
  ["markdown"] = true,
  ["matlab"] = true,
  ["mermaid"] = true,
  ["nginx"] = true,
  ["nim"] = true,
  ["nix"] = true,
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

local function paragraph_block(text)
  return {
    object = "block",
    type = "paragraph",
    paragraph = {
      rich_text = { text_object(text) },
    },
  }
end

local function heading_block(level, text)
  level = math.max(1, math.min(level, 3))
  local key = ("heading_%d"):format(level)
  return {
    object = "block",
    type = key,
    [key] = {
      rich_text = { text_object(text) },
    },
  }
end

local function divider_block()
  return { object = "block", type = "divider", divider = vim.empty_dict() }
end

local function code_block(language, text)
  return {
    object = "block",
    type = "code",
    code = {
      rich_text = { text_object(text) },
      language = normalize_language(language),
    },
  }
end

local function quote_block(text)
  return {
    object = "block",
    type = "quote",
    quote = {
      rich_text = { text_object(text) },
    },
  }
end

local function list_block(block_type, text, children, opts)
  local block = {
    object = "block",
    type = block_type,
    [block_type] = {
      rich_text = { text_object(text) },
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
local function fallback_blocks(bufnr)
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

  local in_code_block = false
  local code_fence = nil
  local code_language = ""
  local code_lines = {}

  local function finish_code_block()
    if not in_code_block then
      return
    end
    table.insert(blocks, code_block(code_language, table.concat(code_lines, "\n")))
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
        if not (push_heading(line) or push_simple_list(line) or push_quote(line) or push_divider(line)) then
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
    return parse_list(node, bufnr)
  elseif ntype == "empty" then
    return nil
  elseif ntype == "html_block" then
    local text = get_node_text(node, bufnr)
    return paragraph_block(text)
  end

  return nil
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
  if #blocks == 0 then
    blocks = fallback_blocks(bufnr)
  end
  return blocks
end

return M
