# notion.nvim

> Bring Notion into Neovim: search pages, edit them as Markdown, and sync changes back with a single write.

## Table of contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Commands](#commands)
- [Configuration reference](#configuration-reference)
- [Buffer lifecycle](#buffer-lifecycle)
- [Notes and limitations](#notes-and-limitations)
- [License](#license)

## Features

- **Page picker** – list database pages via `:NotionList` or the recency-sorted `:NotionListRecent`.
- **Tab-friendly UI** – open any page (picker or explicit ID) in a new Neovim tab instead of a floating window.
- **Inline authoring** – create database entries directly with `:NotionNew`, edit in place, and sync on `:w`.
- **Automatic sync** – write the buffer or run `:NotionSync` to push updates back to Notion.
- **Tree-sitter pipeline** – Markdown → Notion block conversion with safe fallbacks for unsupported content.

## Requirements

- Neovim 0.9 or newer (0.10+ recommended for `vim.system`).
- `tree-sitter-markdown` **and** `markdown_inline` grammars (for example via [`nvim-treesitter`](https://github.com/nvim-treesitter/nvim-treesitter)).
- `curl` available in your `PATH`.
- A Notion integration token that can **read** and **update** the target database/pages.

## Installation

Example using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "2774326573/notion.nvim",
  config = function()
    require("notion").setup({
      token = os.getenv("NOTION_API_TOKEN"),
      database_id = os.getenv("NOTION_DATABASE_ID"),
      title_property = "Name", -- update if your title column has a different name
      sync = { auto_write = true },
      ui = {
        floating = false,
        open_in_tab = true,
      },
    })
  end,
}
```

## Quick start

1. Create a Notion internal integration and copy its secret token.
2. Share the database (or specific pages) with that integration and grant **Can edit** permissions.
3. Export environment variables before launching Neovim:
   - `NOTION_API_TOKEN` – integration secret.
   - `NOTION_DATABASE_ID` – 32-character id from the database URL (strip dashes).
   - Optional: `NOTION_TITLE_PROPERTY` if your title column is not `"Name"`.
4. Install tree-sitter grammars: `:TSInstall markdown markdown_inline`.
5. Restart Neovim and try:
   - `:NotionListRecent` to choose a page.
   - `:NotionOpen <page_id>` to jump straight to a known page.
   - `:NotionNew` to create and open a fresh page.
6. Edit as Markdown and write (`:w`) to sync back to Notion.

## Commands

| Command | Description |
| --- | --- |
| `:NotionList` | List pages using `vim.ui.select`. |
| `:NotionListRecent` | List pages sorted by `last_edited_time`. |
| `:NotionOpen {page_id}` | Open a page directly by its Notion id. |
| `:NotionNew` | Prompt for a title, create a page, then open it. |
| `:NotionSync` | Force a sync of the current buffer back to Notion. |

## Configuration reference

```lua
require("notion").setup({
  token = os.getenv("NOTION_API_TOKEN"),
  token_env = "NOTION_API_TOKEN",
  database_id = os.getenv("NOTION_DATABASE_ID"),
  title_property = os.getenv("NOTION_TITLE_PROPERTY") or "Name",
  notion_version = "2022-06-28",
  timeout = 20000,
  tree_sitter = {
    language = "markdown",
  },
  sync = {
    auto_write = true,
  },
  ui = {
    floating = false,
    open_in_tab = true,
    width = 0.8,
    height = 0.8,
    border = "rounded",
  },
})
```

## Buffer lifecycle

- Buffers are scratch (`buftype="acwrite"`, `bufhidden="wipe"`) and named `notion://{page_id}`.
- Page metadata (id, title, cached blocks) is stored on `vim.b`.
- Successful syncs refresh the cached blocks to minimise future payloads.

## Notes and limitations

- Currently supports common block types: headings, paragraphs, lists, quotes, code blocks, to-dos.
- Unsupported blocks fall back to plain paragraphs to avoid data loss.
- Large pages may take a few seconds to archive old content and append new blocks due to Notion API semantics.

## License

MIT
