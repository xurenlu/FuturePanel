# FuturePanel 项目结构文档

这个文档记录了 FuturePanel 项目的完整文件结构和每个文件的用途。

## 📁 项目概览

FuturePanel 是一个完整的日志监控和面板管理系统，包含以下主要组件：

- **FuturePanel (macOS 应用)**: SwiftUI 编写的 macOS 原生应用
- **Server (Go 服务器)**: 日志接收和处理的后端服务  
- **JSLWatcher (Linux 服务)**: Linux 环境下的日志文件监控和转发服务

## 🗂️ 目录结构

```
FuturePanel/
├── FuturePanel/                    # macOS 应用主目录
├── FuturePanelTests/              # macOS 应用测试
├── FuturePanelUITests/            # macOS 应用 UI 测试
├── server/                        # Go 后端服务器
├── jslwatcher/                    # Linux 日志监控服务
├── .github/                       # GitHub Actions 工作流
├── FuturePanel.xcodeproj/         # Xcode 项目文件
├── 日志面板需求1.0.md              # 项目需求文档
└── PROJECT_STRUCTURE.md           # 本文档
```

## 📱 FuturePanel (macOS 应用)

### 核心文件

| 文件路径 | 用途 | 行数限制 |
|----------|------|----------|
| `FuturePanel/FuturePanelApp.swift` | 应用程序入口，App 生命周期管理 | <500 |
| `FuturePanel/AppDelegate.swift` | 应用委托，处理系统级事件 | <300 |
| `FuturePanel/ContentView.swift` | 主界面视图，日志显示和管理 | <800 |

### 功能模块

| 文件路径 | 用途 | 行数限制 |
|----------|------|----------|
| `FuturePanel/SettingsView.swift` | 设置界面，配置管理 | <500 |
| `FuturePanel/SettingsStore.swift` | 设置数据存储和管理 | <400 |
| `FuturePanel/Theme.swift` | 主题和样式定义 | <300 |
| `FuturePanel/Highlighter.swift` | 语法高亮和文本渲染 | <600 |
| `FuturePanel/TemplateEngine.swift` | 模板引擎，日志格式化 | <800 |

### 服务组件

| 文件路径 | 用途 | 行数限制 |
|----------|------|----------|
| `FuturePanel/WebSocketClient.swift` | WebSocket 客户端，与服务器通信 | <600 |
| `FuturePanel/LogService.swift` | 日志处理服务 | <500 |
| `FuturePanel/LogModels.swift` | 日志数据模型定义 | <400 |

### 资源文件

| 文件路径 | 用途 |
|----------|------|
| `FuturePanel/Assets.xcassets/` | 应用图标、图片等资源 |
| `FuturePanel/Assets.xcassets/AppIcon.appiconset/` | 应用图标集 |
| `FuturePanel/Assets.xcassets/AccentColor.colorset/` | 主题色定义 |

## 🖥️ Server (Go 后端服务)

### 核心文件

| 文件路径 | 用途 | 行数限制 |
|----------|------|----------|
| `server/main.go` | 服务器主程序入口 | <500 |
| `server/go.mod` | Go 模块依赖管理 | <50 |
| `server/go.sum` | 依赖版本锁定 | 自动生成 |

### 功能特性

- WebSocket 服务器，监听端口 8080
- 日志数据接收和处理
- 实时数据转发到客户端
- 支持多客户端连接

## 🔍 JSLWatcher (Linux 日志监控服务)

### 核心架构

| 文件路径 | 用途 | 行数限制 |
|----------|------|----------|
| `jslwatcher/go.mod` | Go 模块依赖管理 | <50 |
| `jslwatcher/cmd/jslwatcher/main.go` | 主程序入口 | <400 |

### 内部模块

| 文件路径 | 用途 | 行数限制 |
|----------|------|----------|
| `jslwatcher/internal/config/config.go` | 配置文件解析和管理 | <600 |
| `jslwatcher/internal/parser/parser.go` | 日志格式解析器 | <800 |
| `jslwatcher/internal/watcher/watcher.go` | 文件系统监控 | <800 |
| `jslwatcher/internal/client/client.go` | WebSocket 客户端 | <600 |

### 部署和配置

| 文件路径 | 用途 |
|----------|------|
| `jslwatcher/scripts/jslwatcher.service` | systemd 服务配置 |
| `jslwatcher/scripts/install.sh` | 一键安装脚本 |
| `jslwatcher/examples/jslwatcher.conf.example` | 配置文件示例 |

### 文档

| 文件路径 | 用途 | 行数限制 |
|----------|------|----------|
| `jslwatcher/README.md` | 完整的使用文档和API说明 | <3000 |

### 支持的日志格式

1. **nginx-access**: Nginx 访问日志 (combined 格式)
2. **nginx-error**: Nginx 错误日志
3. **java-log**: Java 应用日志 (logback/log4j)
4. **php-error**: PHP 错误日志
5. **jsonlines**: JSON Lines 格式

## 🚀 CI/CD 配置

| 文件路径 | 用途 |
|----------|------|
| `.github/workflows/release.yml` | GitHub Actions 自动构建和发布 |

### 构建目标

- **server**: Linux/macOS/Windows 多平台二进制
- **jslwatcher**: Linux 多架构二进制 (amd64/arm64/arm)

## 🧪 测试文件

### macOS 应用测试

| 文件路径 | 用途 |
|----------|------|
| `FuturePanelTests/FuturePanelTests.swift` | 单元测试 |
| `FuturePanelUITests/FuturePanelUITests.swift` | UI 自动化测试 |
| `FuturePanelUITests/FuturePanelUITestsLaunchTests.swift` | 启动测试 |

## 📋 项目配置文件

| 文件路径 | 用途 |
|----------|------|
| `FuturePanel.xcodeproj/` | Xcode 项目配置 |
| `FuturePanel.xcodeproj/project.pbxproj` | 项目构建配置 |
| `FuturePanel.xcodeproj/project.xcworkspace/` | 工作空间配置 |

## 📖 文档文件

| 文件路径 | 用途 | 行数限制 |
|----------|------|----------|
| `日志面板需求1.0.md` | 项目需求和功能规格说明 | <2000 |
| `PROJECT_STRUCTURE.md` | 本文档，项目结构说明 | <3000 |

## 🔧 开发规范

### 文件大小限制

为了保持代码的可维护性，我们设定以下规范：

- **源代码文件**: 最大 2000 行
- **文档文件**: 最大 3000 行
- **配置文件**: 根据实际需要，保持简洁

### 代码组织原则

1. **单一职责**: 每个文件只负责一个明确的功能
2. **模块化**: 相关功能组织在同一目录下
3. **分层架构**: 清晰的应用层、服务层、数据层分离
4. **文档完整**: 每个模块都有对应的文档说明

### 命名规范

- **Swift 文件**: PascalCase (如 `ContentView.swift`)
- **Go 文件**: snake_case (如 `config.go`)
- **目录**: kebab-case 或 lowercase (如 `jslwatcher`, `internal`)
- **配置文件**: dot notation (如 `jslwatcher.conf`)

## 🚦 开发流程

### 1. 新功能开发

1. 在对应模块目录下创建新文件
2. 确保文件行数不超过限制
3. 更新本文档记录新文件
4. 编写对应的测试
5. 更新相关文档

### 2. 文件拆分原则

当文件超过行数限制时：

1. **按功能拆分**: 将不同功能拆分到不同文件
2. **按层次拆分**: 将模型、视图、服务拆分
3. **保持接口简单**: 拆分后确保模块间接口清晰

### 3. 版本发布

1. 更新版本号 (遵循语义化版本)
2. 更新 CHANGELOG
3. 创建 git tag (格式: `1.x.x`)
4. GitHub Actions 自动构建和发布

## 📊 项目统计

### 代码行数统计 (估算)

| 组件 | 文件数 | 代码行数 |
|------|--------|----------|
| macOS 应用 | 8 | ~4000 |
| Go 服务器 | 3 | ~500 |
| JSLWatcher | 5 | ~3000 |
| 配置和脚本 | 4 | ~800 |
| 文档 | 3 | ~5000 |
| **总计** | **23** | **~13300** |

### 技术栈

- **前端**: SwiftUI, Combine
- **后端**: Go, Gorilla WebSocket
- **系统**: systemd, Linux
- **构建**: GitHub Actions, Xcode
- **包管理**: Go Modules, Swift Package Manager

## 🔄 维护计划

### 定期维护

1. **依赖更新**: 每月检查和更新依赖包
2. **安全审计**: 每季度进行安全漏洞扫描
3. **性能优化**: 根据使用情况进行性能调优
4. **文档更新**: 保持文档与代码同步

### 监控指标

1. **应用性能**: 内存使用、CPU 占用
2. **服务可用性**: 连接状态、延迟
3. **错误率**: 日志解析错误、连接失败
4. **用户体验**: 界面响应速度、功能完整性

---

**最后更新**: 2024年12月
**维护者**: rocky
**项目版本**: 1.0.0
