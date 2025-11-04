# notion.nvim

[中文](README.zh-CN.md) | [English](README.md)

在 Neovim 中与 Notion 交互：浏览数据库中的页面、以 Markdown 形式编辑，并把改动同步回 Notion。插件借助官方 Notion API 以及 Neovim 的 tree-sitter `markdown` 解析器完成 Markdown 与块结构的双向转换。

## 功能概览
- `:NotionList`：从指定数据库拉取页面列表并选择打开
- `:NotionOpen {page_id}`：通过页面 ID 直接打开
- `:NotionNew`：创建新页面后自动在缓冲区打开
- `:NotionSync`：将当前缓冲区内容解析后同步到 Notion
- 支持写入自动同步（可配置）
- 借助 tree-sitter `markdown` 解析器在 Markdown 与 Notion Block 之间互转

## 依赖条件
- Neovim 0.9+（推荐 0.10+ 使用 `vim.system`）
- 已安装 `tree-sitter-markdown`（建议通过 [`nvim-treesitter`](https://github.com/nvim-treesitter/nvim-treesitter)）
- 系统可用 `curl`
- 拥有访问数据库权限的 Notion Integration Token

## 安装示例（lazy.nvim）

```lua
{
  "2774326573/notion.nvim",
  config = function()
    require("notion").setup({
      token = os.getenv("NOTION_API_TOKEN"),
      database_id = "你的数据库ID",
      title_property = "Name", -- 根据实际 title 属性名称调整
      sync = {
        auto_write = true,
      },
    })
  end,
}
```

## 常用命令
- `:NotionList` – 调用 `vim.ui.select` 选择并打开页面
- `:NotionOpen {page_id}` – 通过 Notion 页面 ID 打开
- `:NotionNew` – 输入标题后新建页面并打开
- `:NotionSync` – 使用 tree-sitter 解析当前缓冲并同步到 Notion

## 配置项

```lua
require("notion").setup({
  token = os.getenv("NOTION_API_TOKEN"), -- 若未提供会回退到 token_env
  token_env = "NOTION_API_TOKEN",        -- 默认读取的环境变量
  database_id = "YOUR_DATABASE_ID",      -- 必填
  title_property = "Name",               -- 数据库的标题属性
  notion_version = "2022-06-28",         -- 如需，可覆盖 API 版本
  timeout = 20000,                       -- curl 超时（毫秒）
  tree_sitter = {
    language = "markdown",               -- tree-sitter 语言
  },
  sync = {
    auto_write = true,                   -- BufWritePost 自动同步
  },
  ui = {
    floating = true,                     -- 是否用浮窗打开
    width = 0.8,
    height = 0.8,
    border = "rounded",
  },
})
```

### Tree-sitter 提示
插件依赖 Neovim 对 Markdown 的 tree-sitter 支持。请确保 `markdown` 解析器已安装，并在 Notion 缓冲区设置了 `filetype=markdown`。解析器用于提取标题、列表、引用、代码块等结构，从而生成对应的 Notion blocks。

### 令牌获取
`token` 可以在 `setup()` 中直接提供，也可以通过 `token_env` 指定的环境变量（默认 `NOTION_API_TOKEN`）获取。如果两者都为空，插件仍可加载，但涉及 API 的命令会在提示缺少令牌后提前返回。

## 缓冲区生命周期
- 使用 `notion://{page_id}` 命名 scratch 缓冲（`bufhidden=wipe`）
- 缓冲变量保存 `page_id`、页面标题与 block 缓存
- 同步成功后刷新缓存，之后的同步仅发送最新内容

## 注意事项
- 当前仅支持常见块类型（标题、段落、项目符号/编号列表、待办事项、引用、代码块等）
- 富文本标注（加粗、斜体、下划线、行内代码、链接）尽量保留，暂不支持的降级为纯文本
- 不会自动处理数据库模板，如有需要可自行扩展 `:NotionNew`
- 页面过大时同步会较慢，因为需要先归档再追加新块

## 许可协议
MIT
