# notion.nvim

[English](README.md) | [中文](README.zh-CN.md)

Integrate Notion with Neovim. Browse database pages, open them as Markdown buffers, and sync edits back to Notion – powered by the official Notion API and Neovim's tree-sitter Markdown parser.

## Features
- List pages from a configured Notion database via `:NotionList`
- Open a page in a scratch Markdown buffer with `:NotionOpen {page_id}`
- Create a new page in the database using `:NotionNew`
- Sync changes from the current buffer back to Notion blocks with `:NotionSync`
- Automatic sync on write (configurable)
- Markdown ⇄ Notion block conversion driven by Neovim's tree-sitter (`markdown` parser)

## Requirements
- Neovim 0.9+ (0.10+ recommended for `vim.system`)
- [`tree-sitter-markdown`](https://github.com/MDeiml/tree-sitter-markdown) installed (e.g. via [`nvim-treesitter`](https://github.com/nvim-treesitter/nvim-treesitter))
- Curl executable available in your `$PATH`
- Notion integration token with access to the target database

## Installation

Example using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "2774326573/notion.nvim",
  config = function()
    require("notion").setup({
      token = os.getenv("NOTION_API_TOKEN"),
      database_id = "YOUR_DATABASE_ID",
      title_property = "Name", -- adapt to your database title property
      sync = {
        auto_write = true,
      },
    })
  end,
}
```

## Commands
- `:NotionList` – interactive picker (uses `vim.ui.select`) to choose and open a page
- `:NotionOpen {page_id}` – open a page directly by Notion page ID
- `:NotionNew` – prompt for a title, create a new page, and open it
- `:NotionSync` – parse the current buffer with tree-sitter and push it to Notion

## Configuration

```lua
require("notion").setup({
  token = os.getenv("NOTION_API_TOKEN"), -- required
  database_id = "YOUR_DATABASE_ID",      -- required
  title_property = "Name",               -- name of the title property in the database
  notion_version = "2022-06-28",         -- override if Notion updates API version
  timeout = 20000,                       -- curl timeout in milliseconds
  tree_sitter = {
    language = "markdown",               -- tree-sitter language to parse buffers
  },
  sync = {
    auto_write = true,                   -- automatically sync on BufWritePost
  },
  ui = {
    floating = true,                     -- use floating window when opening pages
    width = 0.8,
    height = 0.8,
    border = "rounded",
  },
})
```

### Tree-sitter
The plugin relies on Neovim's tree-sitter integration to understand Markdown structure. Ensure the `markdown` parser is installed, and your `filetype` is set to `markdown` in Notion buffers. The parser powers both block generation during sync and lightweight structural queries (e.g. headings, lists, quotes, code fences).

## Buffer lifecycle
- Buffers are scratch (`buftype=""`, `bufhidden="wipe"`) and named `notion://{page_id}` for easier identification.
- Page metadata (`page_id`, `version`, cached blocks) is stored in buffer variables.
- When sync succeeds the cache refreshes, ensuring subsequent updates only re-upload new content.

## Notes / Limitations
- Only a subset of Notion block types is currently supported (headings, paragraphs, bulleted/numbered lists, quotes, code blocks, to-dos).
- Rich text annotations (bold/italic/underline/code/link) round-trip where possible; unsupported annotations degrade to plain text.
- Database templates are not fetched automatically; customise `:NotionNew` logic if you require more properties.
- For large pages, syncing may take a few seconds due to block archival + append semantics.

## License
MIT
"# notion.nvim" 
