# Toolbox Flutter

本地优先的开发者工具箱，使用 **Flutter + Dart** 重写原 Electron + React 版本。当前实现第一个工具：**接口请求（API Client）**。

## 功能

- GET / POST / PUT / PATCH / DELETE / HEAD / OPTIONS
- Query、Headers 表格编辑，URL 查询参数自动拆分
- Body：none / JSON / Text / form-urlencoded / form-data（文本字段）
- Auth：Bearer / Basic / API Key（Header / Query）
- 环境变量与全局变量，`{{变量名}}` 插值，敏感值遮罩
- 请求历史、收藏、请求草稿自动保存
- 响应状态、耗时、大小、Headers、JSON 高亮、原始响应
- 请求详情：实际 URL、最终请求头、请求体、插件执行日志
- 请求扩展：HMAC-SHA256 签名、AES-256-GCM 加解密
- 超时、HTTPS 证书校验、HTTP 代理
- 深色 / 浅色主题
- 工作区导入 / 导出（纯 Dart 文件浏览器，不依赖原生插件）
- 兼容导入原 Electron 版本的 `workspace.json`

## 技术栈

| 层级 | 选型 |
| --- | --- |
| 桌面端 | Flutter 3.47+ / Dart 3.13+ |
| 状态 | `ChangeNotifier` + `InheritedNotifier` |
| 请求引擎 | `dart:io` `HttpClient`（主 Isolate 发送，不受 CORS 限制） |
| 加密 | `pointycastle`（HMAC-SHA256 / AES-256-GCM） |
| 存储 | `%APPDATA%\Toolbox\workspace.json` |
| 测试 | `flutter_test` |

## 开发

要求：

- Flutter 3.47 或更高版本
- Windows 桌面开发需要安装 Visual Studio 2022，并勾选 **Desktop development with C++** 工作负载
- 项目未使用原生插件，因此不需要开启 Windows 开发者模式（Developer Mode）

```bash
flutter pub get
flutter run -d windows   # 开发运行
flutter test             # 单元与界面冒烟测试
flutter analyze          # 静态检查
flutter build windows    # 构建 Release
```

构建产物位于 `build\windows\x64\runner\Release\`。

如果 Flutter 不在 PATH 中，可直接使用 SDK 的完整路径，例如：

```powershell
D:\flutter\bin\flutter.bat run -d windows
```

## 目录结构

```text
toolbox_flutter/
├─ lib/
│  ├─ main.dart                 # 启动、生命周期、退出前保存
│  ├─ app.dart                  # MaterialApp、AppStateScope
│  ├─ models/                   # 数据模型、默认值、插件定义、工作区归一化
│  ├─ services/
│  │  ├─ storage_service.dart   # 工作区读写、导入导出
│  │  └─ request/
│  │     ├─ pipeline.dart       # 变量解析 → 认证 → 插件 → 发送 → 响应处理
│  │     ├─ plugins.dart        # HMAC / AES 插件实现
│  │     ├─ interpolate.dart    # {{变量}} 插值
│  │     └─ headers.dart        # 大小写不敏感请求头工具
│  ├─ state/app_state.dart      # 全局状态与自动保存
│  ├─ screens/                  # 主界面、环境变量弹窗
│  ├─ widgets/                  # 请求/响应面板、编辑器、通用组件
│  └─ theme/app_theme.dart      # 深色/浅色主题
├─ test/                        # 插值、插件、Schema、工具函数、界面冒烟测试
└─ windows/                     # Flutter Windows Runner
```

## 工作区与迁移

Flutter 版本默认将工作区保存到：

```text
%APPDATA%\Toolbox\workspace.json
```

首次启动时，如果该文件不存在，会自动尝试读取 Electron 版本的：

```text
%APPDATA%\toolbox\workspace.json
```

也可以在「环境与变量 → 导入」中选择旧的 `workspace.json`。导入会覆盖当前工作区，建议先导出备份。

## 与 Electron 版本的差异

- 请求引擎从 `undici` 改为 Dart `HttpClient`，HTTPS 证书校验、代理、超时、取消、multipart 文本字段均已实现。
- 代码编辑器为自研轻量实现，支持行号、JSON 语法高亮、只读响应预览；超过 20 万字符时自动关闭高亮以保证性能。
- 文件导入/导出使用内置目录浏览器，避免依赖原生文件选择插件。
- 导出文件格式与原版本保持一致（`version: 1`），双向兼容。
