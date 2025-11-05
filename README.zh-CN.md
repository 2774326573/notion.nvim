# notion.nvim

> 在 Neovim 中浏览、编辑并同步 Notion 页面，让 Markdown 工作流无缝接入 Notion。

## 目录

- [功能亮点](#功能亮点)
- [环境要求](#环境要求)
- [安装示例](#安装示例)
- [快速上手](#快速上手)
- [常用命令](#常用命令)
- [配置参考](#配置参考)
- [多数据库示例](#多数据库示例)
- [缓冲区说明](#缓冲区说明)
- [注意事项](#注意事项)
- [许可证](#许可证)

## 功能亮点

- **页面选择器：** 使用 `:NotionList` 或 `:NotionListRecent` 快速列出数据库页面。
- **标签页友好：** 无论是列表选择还是指定 ID，页面都会在新的 Neovim 标签页中打开。
- **内置新建：** 通过 `:NotionNew` 直接在数据库中新建页面并立刻编辑。
- **自动同步：** 保存（`:w`）或执行 `:NotionSync` 即可把改动推回 Notion。
- **tree-sitter 管线：** Markdown ↔ Notion Block 转换安全可靠，无法解析的内容会退化为普通段落。
- **多数据库支持：** 同时配置多个数据库，并通过 `:NotionSelectDatabase` 快速切换。

## 环境要求

- Neovim 0.9 及以上版本（推荐 0.10+ 以使用 `vim.system`）。
- 已安装 `tree-sitter-markdown` 和 `markdown_inline`（可通过 [`nvim-treesitter`](https://github.com/nvim-treesitter/nvim-treesitter) 安装）。
- 系统 `PATH` 中可访问 `curl`。
- 拥有目标数据库 **读取** 与 **更新** 权限的 Notion 集成密钥。

## 安装示例

以下示例使用 [lazy.nvim](https://github.com/folke/lazy.nvim)：

```lua
{
  "2774326573/notion.nvim",
  config = function()
    require("notion").setup({
      token = os.getenv("NOTION_API_TOKEN"),
      database_id = os.getenv("NOTION_DATABASE_ID"),
      title_property = os.getenv("NOTION_TITLE_PROPERTY") or "Name",
      sync = { auto_write = true },
      ui = {
        floating = false,
        open_in_tab = true,
      },
    })
  end,
}
```

## 快速上手

1. 在 Notion 创建内部集成，并复制集成密钥。
2. 将目标数据库（或单独页面）分享给该集成，并授予“可编辑”权限。
3. 启动 Neovim 之前设置环境变量：
   - `NOTION_API_TOKEN`：集成密钥。
   - `NOTION_DATABASE_ID`：数据库链接中的 32 位 ID（去掉短横线）。
   - `NOTION_TITLE_PROPERTY`：可选，若数据库标题列不是 "Name"。
4. 安装 tree-sitter 语法：`:TSInstall markdown markdown_inline`。
5. 重启 Neovim 并尝试：
   - `:NotionListRecent` 查看最近编辑的页面；
   - `:NotionOpen <page_id>` 直接打开指定页面；
   - `:NotionNew` 新建页面并立即进入编辑。
6. 像普通 Markdown 一样编辑，执行 `:w` 即同步回 Notion；如果配置了多个数据库，可用 `:NotionSelectDatabase` 切换当前数据库。

## 常用命令

| 命令 | 说明 |
| --- | --- |
| `:NotionList` | 使用 `vim.ui.select` 列出并选择页面 |
| `:NotionListRecent` | 按最后编辑时间倒序列出页面 |
| `:NotionOpen {page_id}` | 根据页面 ID 直接打开 |
| `:NotionNew` | 新建页面并立即打开 |
| `:NotionSync` | 手动同步当前缓冲区 |
| `:NotionSelectDatabase` | 在配置了多个数据库时切换当前数据库 |

## 配置参考

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

## 多数据库示例

```lua
require("notion").setup({
  token = os.getenv("NOTION_API_TOKEN"),
  databases = {
    { name = "个人", id = os.getenv("NOTION_DB_PERSONAL"), title_property = "Name" },
    { name = "工作", id = os.getenv("NOTION_DB_WORK"), title_property = "Title" },
  },
  default_database = "个人",
  sync = { auto_write = true },
})
```

也可以通过设置以逗号分隔的 `NOTION_DATABASE_IDS`（以及可选的 `NOTION_DEFAULT_DATABASE`）环境变量，让示例配置自动注册多个数据库。

## 缓冲区说明

- 打开的页面命名为 `notion://{page_id}`，缓冲区类型为 `acwrite`，关闭后自动清理（`bufhidden="wipe"`）。
- `vim.b` 中保存页面 ID、标题以及缓存的 blocks；同步成功后会刷新缓存，避免重复上传。
- 同步失败会给出错误提示，原内容不会被覆盖，可再次尝试。

## 注意事项

- 当前支持的 Block 类型包括标题、段落、列表、引用、代码块、待办等常用结构。
- 不支持的 Block 会自动降级为普通段落，以防止内容丢失。
- 由于 Notion API 需要先归档旧 Block 再追加新内容，大型页面同步时可能需要数秒。

## 许可证

MIT

