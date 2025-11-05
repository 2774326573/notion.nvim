# notion.nvim

> 在 Neovim 中无缝浏览、编辑并同步 Notion 页面，让 Markdown 工作流直接打通到 Notion。

## 目录

- [功能亮点](#功能亮点)
- [环境要求](#环境要求)
- [安装示例](#安装示例)
- [快速上手](#快速上手)
- [常用命令](#常用命令)
- [配置参考](#配置参考)
- [缓冲区说明](#缓冲区说明)
- [注意事项](#注意事项)
- [许可证](#许可证)

## 功能亮点

- **页面选择器**：`:NotionList` / `:NotionListRecent` 从数据库列出页面，支持按最近编辑排序。
- **标签页友好**：无论是列表选择还是指定 ID，页面都会在新的 Neovim 标签页中打开，避免弹窗打断。
- **内置新建**：通过 `:NotionNew` 在数据库里直接创建页面并立即编辑。
- **自动同步**：保存（`:w`）或执行 `:NotionSync` 即可把改动推回 Notion。
- **tree-sitter 管线**：Markdown ↔ Notion Block 之间安全转换，无法识别的内容自动降级成段落以防丢失。

## 环境要求

- Neovim 0.9 及以上版本（推荐 0.10+ 以使用 `vim.system`）。
- `tree-sitter-markdown` 与 `markdown_inline` 语法（可通过 [`nvim-treesitter`](https://github.com/nvim-treesitter/nvim-treesitter) 安装）。
- 系统 `PATH` 中可访问 `curl`。
- 拥有目标数据库 **读取** 和 **更新** 权限的 Notion 集成 Token。

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
2. 将目标数据库（或单独页面）分享给该集成，授予“可编辑”权限。
3. 在启动 Neovim 前设置环境变量：
   - `NOTION_API_TOKEN`：集成密钥。
   - `NOTION_DATABASE_ID`：数据库链接中的 32 位 ID（去掉短横线）。
   - 可选 `NOTION_TITLE_PROPERTY`：若数据库标题列名称不是 `"Name"`。
4. 安装 tree-sitter 语法：`:TSInstall markdown markdown_inline`。
5. 重启 Neovim，并尝试：
   - `:NotionListRecent` 打开最近编辑的页面。
   - `:NotionOpen <page_id>` 直接定位到指定页面。
   - `:NotionNew` 新建页面并立即打开。
6. 像普通 Markdown 一样编辑，执行 `:w` 即同步回 Notion，成功后会提示 `[notion.nvim] Page synced successfully.`。

## 常用命令

| 命令 | 说明 |
| --- | --- |
| `:NotionList` | 使用 `vim.ui.select` 列出并选择页面。 |
| `:NotionListRecent` | 按最后编辑时间倒序列出页面。 |
| `:NotionOpen {page_id}` | 通过页面 ID 直接打开。 |
| `:NotionNew` | 输入标题后在数据库中新建页面。 |
| `:NotionSync` | 手动触发当前缓冲区同步。 |

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

## 缓冲区说明

- 打开的页面命名为 `notion://{page_id}`，类型为 `acwrite`，关闭后自动释放（`bufhidden="wipe"`）。
- `vim.b` 中保存了页面 ID、标题和缓存的 blocks，同步成功会刷新缓存，避免重复上传。
- 如果同步失败，会弹出错误提示，原内容保持不变，方便再次尝试。

## 注意事项

- 当前支持的 Block 类型包括：标题、段落、列表、引用、代码块、待办等。
- 不支持的 Block 会自动降级为普通段落，以防止内容丢失。
- Notion API 会先归档旧 Block 再追加新内容，所以大型页面同步时可能需要几秒。

## 许可证

MIT
