# notion.nvim

> Bring Notion into Neovim: search pages, edit them as Markdown, and sync changes back with a single write.

## Table of contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Commands](#commands)
- [Configuration reference](#configuration-reference)
- [Multiple databases](#multiple-databases)
- [Buffer lifecycle](#buffer-lifecycle)
- [Notes and limitations](#notes-and-limitations)
- [License](#license)

## Features

- **Page picker:** list database pages via `:NotionList` or the recency-sorted `:NotionListRecent`.
- **Tab-friendly UI:** open any page (picker or explicit ID) in a new Neovim tab instead of a floating window.
- **Inline authoring:** create database entries directly with `:NotionNew`, edit in place, and sync on `:w`.
- **Automatic sync:** write the buffer or run `:NotionSync` to push updates back to Notion.
- **Cached listings:** avoid refetching large databases by caching results (configurable TTL); use `:NotionRefreshPages` to force a refresh.
- **Tree-sitter pipeline:** Markdown-to-Notion block conversion with safe fallbacks for unsupported content.
- **Multi-database aware:** declare several databases and switch with `:NotionSelectDatabase`; the plugin remembers your last choice across sessions.

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
  branch = "newMain",
  config = function()
    require("notion").setup({
      token = os.getenv("NOTION_API_TOKEN"),
      databases = {
        { name = "CMake Study",      id = "2a1c19f476e380e5b1f1e6dd98987a20" },
        { name = "CPP Study",        id = "2a1c19f476e380c09aa0c46ab440fb04" },
        { name = "Python Study",     id = "2a2c19f476e3817494b0d06e510a66a9" },
        { name = "OpenCV Study",     id = "275c19f476e3800a896ac0beec2f24f7" },
        { name = "CSharp Study",     id = "2a2c19f476e380f3a79fcefe671fcab4" },
        { name = "Notebook",         id = "275c19f476e380a7b4bbe0969e728279" },
        { name = "Today's Tasks",    id = "272c19f476e3804b81a7c5e625e6960b" },
        { name = "Daily Journal",    id = "275c19f476e3800e869cd8957b05a7d4" },
        { name = "WeChat Reading",   id = "275c19f476e38126aa65d18b1c61d027" },
      },
      default_database = "CMake Study",
      title_property = os.getenv("NOTION_TITLE_PROPERTY") or "Name",
      sync = { auto_write = true },
      parser = {
        preserve_code_fences = false, -- true keeps ```fences; false sends Notion code blocks
      },
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
3. Provide your API token in one of the following ways:
   - Set `NOTION_API_TOKEN` before launching Neovim, or
   - Run `:NotionSetToken` (uses `vim.ui.input`; works on Windows, macOS, and Linux, persisting the token to `stdpath('data')/notion.nvim/token.txt`; commands that need the token will prompt once when it is missing—press Cancel to defer and you will not be prompted again until you run `:NotionSetToken`).
   - Optional: `NOTION_TITLE_PROPERTY` if your title column is not `"Name"`.
4. Install tree-sitter grammars: `:TSInstall markdown markdown_inline`.
5. Restart Neovim and try:
   - `:NotionListRecent` to choose a page.
   - `:NotionOpen <page_id>` to jump straight to a known page.
   - `:NotionNew` to create and open a fresh page.
6. Edit as Markdown and write (`:w`) to sync back to Notion. Use `:NotionSelectDatabase` (or your own key bindings) to switch databases when needed.

## Commands

| Command | Description |
| --- | --- |
| `:NotionList` | List pages using `vim.ui.select`. |
| `:NotionListRecent` | List pages sorted by `last_edited_time`. |
| `:NotionOpen {page_id}` | Open a page directly by its Notion id. |
| `:NotionNew` | Prompt for a title, create a page, then open it. |
| `:NotionSync` | Force a sync of the current buffer back to Notion. |
| `:NotionSetToken` | Prompt for and persist the API token via `vim.ui.input`. |
| `:NotionDeletePage [id]` | Archive/delete a page (defaults to the current buffer's page). |
| `:NotionRefreshPages` | Clear the cached listing for the current database and refetch it. |
| `:NotionSelectDatabase` | Pick the active database when multiple are configured. |

## Configuration reference

```lua
require("notion").setup({
  token = os.getenv("NOTION_API_TOKEN"),
  title_property = os.getenv("NOTION_TITLE_PROPERTY") or "Name",
  databases = {
    { name = "CMake Study",   id = "2a1c19f476e380e5b1f1e6dd98987a20" },
    { name = "CPP Study",     id = "2a1c19f476e380c09aa0c46ab440fb04" },
    { name = "Python Study",  id = "2a2c19f476e3817494b0d06e510a66a9" },
    { name = "OpenCV Study",  id = "275c19f476e3800a896ac0beec2f24f7" },
    { name = "CSharp Study",  id = "2a2c19f476e380f3a79fcefe671fcab4" },
  },
  default_database = "CMake Study",
  sync = {
    auto_write = true,
  },
  parser = {
    preserve_code_fences = false, -- set true to upload ``` fenced blocks verbatim
  },
  cache = {
    ttl = 60, -- seconds; set to 0 or negative to disable caching, nil for unlimited
  },
  ui = {
    floating = false,
    open_in_tab = true,
  },
})
```

`cache.ttl` controls how long (in seconds) the page list stays in memory. Set it to a positive number (default `60`) to reuse results, `0` or a negative number to disable caching, or `nil` for unlimited caching.

## Multiple databases

The sample configuration above hard-codes multiple databases with friendly names. The plugin also remembers the last selected database between sessions. If you prefer to generate the list dynamically (for example from an external script), do so before calling `require("notion").setup`.

## Buffer lifecycle

- Buffers are scratch (`buftype="acwrite"`, `bufhidden="wipe"`) and named `notion://{page_id}`.
- Page metadata (id, title, cached blocks) is stored on `vim.b`.
- Successful syncs refresh the cached blocks to minimise future payloads.

## Notes and limitations

- Currently supports common block types: headings, paragraphs, lists, quotes, code blocks, to-dos.
- Unsupported blocks fall back to plain paragraphs to avoid data loss.
- Large pages may take a few seconds to archive old content and append new blocks due to Notion API semantics.

## Acknowledgements

- Similar project: [AI0den/notion.nvim](https://github.com/AI0den/notion.nvim).
- That project highlights the following tools:
  - [impulse.nvim](https://github.com/mvllow/impulse.nvim) – inspiration for the core idea.
  - [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) – asynchronous job helpers.
  - [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) – picker UX building blocks.

## License

MIT
