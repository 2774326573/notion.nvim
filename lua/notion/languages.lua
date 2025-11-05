local M = {}

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
}

local preferred_labels = {
  cpp = "c++",
  csharp = "c#",
  fsharp = "f#",
}

local function normalize(language)
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
  local hyphenated = lang:gsub("%s+", "-")
  hyphenated = language_aliases[hyphenated] or hyphenated
  if notion_languages[hyphenated] then
    return hyphenated
  end
  return "plain text"
end

function M.normalize(language)
  return normalize(language)
end

function M.display(language)
  if language == nil or language == "" then
    return ""
  end
  if vim and language == vim.NIL then
    return ""
  end
  local normalized = normalize(language)
  if normalized == "plain text" then
    return ""
  end
  local preferred = preferred_labels[normalized]
  if preferred then
    return preferred
  end
  return language
end

return M
