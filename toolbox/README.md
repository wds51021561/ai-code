# Toolbox

本地优先的开发者工具箱。顶部标签页用于承载不同工具，当前实现第一个工具：**接口请求（API Client）**。

## 功能

- GET / POST / PUT / PATCH / DELETE / HEAD / OPTIONS
- Query、Headers 表格编辑，URL 查询参数自动拆分
- Body：none / JSON / Text / form-urlencoded / form-data（文本字段）
- Auth：Bearer / Basic / API Key（Header 或 Query）
- 环境变量与全局变量，`{{变量名}}` 插值，敏感值遮罩
- 请求历史、收藏、请求草稿自动保存
- 响应状态、耗时、大小、Headers、JSON 高亮、原始响应
- 请求详情：实际 URL、最终请求头、请求体、插件执行日志
- 请求扩展：HMAC-SHA256 签名、AES-256-GCM 加解密
- 超时、HTTPS 证书校验、HTTP 代理
- 深色 / 浅色主题
- 工作区导入 / 导出

## 技术栈

| 层 | 选型 |
| --- | --- |
| 桌面壳 | Electron + electron-vite + electron-builder |
| 前端 | React 19 + TypeScript + Vite |
| 样式 | Tailwind CSS 4 + lucide-react |
| 编辑器 | CodeMirror 6 |
| 状态 | Zustand |
| 校验 | Zod |
| 请求引擎 | Node `undici`（主进程发送，无 CORS 限制） |
| 存储 | Electron `userData/workspace.json` |
| 测试 | Vitest |

## 开发

要求：Node.js >= 22.12。

```bash
npm install
npm run dev        # 开发模式
npm test           # 单元测试
npm run typecheck  # 类型检查
npm run build      # 构建 renderer + main + preload
npm run package    # 打包 Windows NSIS 安装包
```

> 安装包未配置代码签名证书，Windows SmartScreen 可能提示未知发布者。

> 如果 Electron 二进制下载失败，可设置镜像后重新安装：
>
> ```powershell
> $env:ELECTRON_MIRROR="https://npmmirror.com/mirrors/electron/"
> node node_modules/electron/install.js
> ```
>
> 如果打包时 electron-builder 依赖下载失败，可设置：
>
> ```powershell
> $env:ELECTRON_BUILDER_BINARIES_MIRROR="https://npmmirror.com/mirrors/electron-builder-binaries/"
> ```

## 目录结构

```text
toolbox/
├─ resources/              # 应用图标等资源
├─ electron.vite.config.ts
├─ shared/                 # 前后端共享类型、默认值、Zod Schema、插件元数据
├─ src/
│  ├─ main/                # Electron 主进程
│  │  ├─ index.ts          # 窗口、IPC、生命周期
│  │  ├─ storage.ts        # 工作区读写、导入导出
│  │  └─ request/
│  │     ├─ pipeline.ts    # 变量解析 → 认证 → 插件 → 发送 → 响应处理
│  │     ├─ plugins.ts     # HMAC / AES 插件实现
│  │     └─ headers.ts
│  ├─ preload/             # contextBridge 白名单 API
│  └─ renderer/src/
│     ├─ tools/
│     │  ├─ registry.ts    # 工具注册表，自动生成顶部标签页
│     │  └─ api-client/    # 接口请求工具
│     ├─ components/       # 通用 UI
│     ├─ store/            # Zustand 状态
│     └─ lib/
└─ out/                    # 构建产物
```

## 扩展工具

在 `src/renderer/src/tools/` 下新建工具目录，然后在 `src/renderer/src/tools/registry.ts` 注册：

```ts
{
  id: 'json-formatter',
  title: 'JSON 工具',
  description: '格式化与对比 JSON',
  icon: Braces,
  component: lazy(() => import('./json-formatter'))
}
```

顶部标签页会自动生成，不需要修改应用壳。

## 扩展请求插件

插件接口位于 `src/main/request/plugins.ts`：

```ts
export interface RequestPlugin {
  id: string
  beforeSend?: (context: RequestPluginContext, config: Record<string, unknown>) => void
  afterResponse?: (context: ResponsePluginContext, config: Record<string, unknown>) => string
}
```

添加步骤：

1. 在 `shared/plugins.ts` 中添加插件元数据、配置模板和配置说明（渲染层自动生成配置界面）。
2. 在 `src/main/request/plugins.ts` 中实现 `beforeSend` / `afterResponse`。
3. 将实现注册到 `PLUGIN_IMPLEMENTATIONS`。

执行顺序：

```text
变量解析 → 认证 → 插件 beforeSend（按列表顺序）→ 发送
     → 响应体读取 → 插件 afterResponse（逆序）→ 返回渲染层
```

插件配置值同样支持 `{{变量}}`，并在主进程执行前解析。

## 环境变量

- 全局变量始终生效。
- 当前环境变量覆盖全局同名变量。
- 支持 URL、Params、Headers、Body、Auth、插件配置。
- 值为空或未启用的变量会被忽略。
- 敏感变量在界面中遮罩显示；工作区导出文件包含真实值，请妥善保管。

## 数据与安全

- 所有工作区数据保存在 Electron `userData` 目录下的 `workspace.json`。
- 请求由主进程发送，仅允许 `http://` / `https://`。
- 响应体最多读取 15 MB，超出部分会标记截断。
- 渲染进程启用 `contextIsolation`、`sandbox`，关闭 `nodeIntegration`，并通过 CSP 限制资源。
- 外部链接使用系统浏览器打开，禁止在应用内导航。
