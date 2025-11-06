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
- **页面缓存：** 页面列表会在内存中缓存（可配置 TTL），避免每次切换都重新请求；需要时可用 `:NotionRefreshPages` 强制刷新。
- **tree-sitter 管线：** Markdown ↔ Notion Block 转换安全可靠，无法解析的内容会退化为普通段落。
- **多数据库支持：** 在配置中声明多个数据库，使用 `:NotionSelectDatabase` 快速切换；插件会在会话之间记住你上次选择的数据库。

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
  branch = "newMain",
  config = function()
    require("notion").setup({
      token = os.getenv("NOTION_API_TOKEN"),
      databases = {
        { name = "CMake学习",   id = "2a1c19f476e380e5b1f1e6dd98987a20" },
        { name = "CPP学习",     id = "2a1c19f476e380c09aa0c46ab440fb04" },
        { name = "Python学习",  id = "2a2c19f476e3817494b0d06e510a66a9" },
        { name = "OpenCV学习",  id = "275c19f476e3800a896ac0beec2f24f7" },
        { name = "CSharp学习",  id = "2a2c19f476e380f3a79fcefe671fcab4" },
        { name = "随心笔记",   id = "275c19f476e380a7b4bbe0969e728279" },
        { name = "今日代办",   id = "272c19f476e3804b81a7c5e625e6960b" },
        { name = "每日日记",   id = "275c19f476e3800e869cd8957b05a7d4" },
        { name = "微信阅读",   id = "275c19f476e38126aa65d18b1c61d027" },
      },
      default_database = "CMake学习",
      title_property = os.getenv("NOTION_TITLE_PROPERTY") or "Name",
      sync = { auto_write = true },
      parser = {
        preserve_code_fences = false, -- 设为 true 时上传原始 ``` 围栏文本
      },
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
3. 提供 API 密钥（任选其一）：
   - 在启动前设置 `NOTION_API_TOKEN`；
   - 或运行 `:NotionSetToken`（通过 `vim.ui.input` 弹窗输入，Windows/macOS/Linux 均适用，并会将密钥保存到 `stdpath('data')/notion.nvim/token.txt`；首次缺少密钥时相关命令会弹窗，按下 Cancel 即可暂时跳过，之后不会再提示，待准备好再执行 `:NotionSetToken`）。
   - 可选 `NOTION_TITLE_PROPERTY`：若标题列不是 `"Name"`。
4. 安装 tree-sitter 语法：`:TSInstall markdown markdown_inline`。
5. 重启 Neovim，并尝试：
   - `:NotionListRecent` 查看最近编辑的页面；
   - `:NotionOpen <page_id>` 直接打开指定页面；
   - `:NotionNew` 新建页面并立即进入编辑。
6. 像普通 Markdown 一样编辑，执行 `:w` 即同步回 Notion；如需切换数据库，可使用 `:NotionSelectDatabase` 或自定义快捷键。

## 常用命令

| 命令 | 说明 |
| --- | --- |
| `:NotionList` | 使用 `vim.ui.select` 列出并选择页面 |
| `:NotionListRecent` | 按最后编辑时间倒序列出页面 |
| `:NotionOpen {page_id}` | 根据页面 ID 直接打开 |
| `:NotionNew` | 新建页面并立即打开 |
| `:NotionSync` | 手动同步当前缓冲区 |
| `:NotionSetToken` | 弹窗输入并保存 API 密钥 |
| `:NotionDeletePage [id]` | 删除（归档）指定页面，若省略 ID 则默认当前缓冲区 |
| `:NotionRefreshPages` | 清除当前数据库缓存并重新获取 |
| `:NotionSelectDatabase` | 多数据库环境下切换当前数据库 |

## 配置参考

```lua
require("notion").setup({
  token = os.getenv("NOTION_API_TOKEN"),
  title_property = os.getenv("NOTION_TITLE_PROPERTY") or "Name",
  databases = {
    { name = "CMake学习",  id = "2a1c19f476e380e5b1f1e6dd98987a20" },
    { name = "CPP学习",    id = "2a1c19f476e380c09aa0c46ab440fb04" },
    { name = "Python学习", id = "2a2c19f476e3817494b0d06e510a66a9" },
    { name = "OpenCV学习", id = "275c19f476e3800a896ac0beec2f24f7" },
    { name = "CSharp学习", id = "2a2c19f476e380f3a79fcefe671fcab4" },
  },
  default_database = "CMake学习",
  sync = { auto_write = true },
  parser = {
    preserve_code_fences = false, -- true 保留 ``` 围栏为纯文本
  },
  cache = { ttl = 60 }, -- 以秒为单位；设为 0 或负数禁用，设为 nil 则无限缓存
  ui = {
    floating = false,
    open_in_tab = true,
  },
})
```

`cache.ttl` 用来控制页面列表的缓存时间（秒）。设置为正数（默认 60）代表在该时间内复用数据，设为 0 或负数禁用缓存，设为 `nil` 则不限时缓存。

## 多数据库示例

上面的示例直接在配置中写死了多个数据库并给出友好的名称。插件会在不同 Neovim 会话之间记住你上次选择的数据库。如果希望从外部脚本或环境变量动态生成列表，只需在调用 `require("notion").setup` 之前构造好对应的 Lua 表。

## 致谢

- 类似项目：[AI0den/notion.nvim](https://github.com/AI0den/notion.nvim)。
- 该项目引用：
  - [impulse.nvim](https://github.com/mvllow/impulse.nvim) —— 提供灵感。
  - [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) —— 异步任务支持。
  - [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) —— 选择器体验。

## 缓冲区说明

- 打开的页面命名为 `notion://{page_id}`，缓冲区类型为 `acwrite`，关闭后自动清理（`bufhidden="wipe"`）。
- `vim.b` 中保存页面 ID、标题以及缓存的 blocks；同步成功后会刷新缓存，避免重复上传。
- 同步失败会给出错误提示，原内容不会被覆盖，可再次尝试。

## 注意事项

- 当前支持的 Block 类型包括标题、段落、列表、引用、代码块、待办等常用结构。
- 不支持的 Block 会自动降级为普通段落，以防止内容丢失。
- 由于 Notion API 需要先归档旧块再追加新内容，大型页面同步时可能需要数秒。

## 许可证

MIT
