# JSLWatcher

JSLWatcher 是一个高性能的日志文件监控和转发服务，专为 Linux 系统设计。它能够实时监控多个日志文件，解析不同格式的日志内容，并通过 HTTP POST 将结构化的日志数据转发到内置服务器域名指定的 URI 路径。

## ✨ 主要特性

- 🔄 **实时监控**: 使用 fsnotify 实现高效的文件系统监控
- 📝 **多格式支持**: 内置 Nginx、Java、PHP 等常见日志格式解析器
- 🌐 **HTTP 转发**: 将日志 JSON 通过 HTTP POST 转发到内置域名（`https://future.some.im`、`https://future.wxside.com`）下的 URI 路径
- 🔧 **简化配置**: YAML 配置只需指定文件与要发送到的 `paths`
- 🚀 **高性能**: Go 语言编写，低内存占用，高并发处理
- 🛡️ **安全设计**: systemd 集成，完整的权限控制
- 📦 **一键安装**: 提供自动化安装脚本，支持多个 Linux 发行版

## 🚀 快速开始

### 一键安装

```bash
# 下载并执行安装脚本
curl -fsSL https://raw.githubusercontent.com/xurenlu/FuturePanel/main/jslwatcher/scripts/install.sh | sudo bash

# 或者先下载再执行
wget https://raw.githubusercontent.com/xurenlu/FuturePanel/main/jslwatcher/scripts/install.sh
chmod +x install.sh
sudo ./install.sh
```

### 手动安装

1. **下载二进制文件**

```bash
# 获取最新版本
VERSION=$(curl -s https://api.github.com/repos/xurenlu/FuturePanel/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

# 下载对应架构的二进制文件 (以 linux/amd64 为例)
wget https://github.com/xurenlu/FuturePanel/releases/download/$VERSION/jslwatcher_${VERSION}_linux_amd64.tar.gz

# 解压并安装
tar -xzf jslwatcher_${VERSION}_linux_amd64.tar.gz
sudo mv jslwatcher /usr/local/bin/
sudo chmod +x /usr/local/bin/jslwatcher
```

2. **创建系统用户和目录**

```bash
# 创建系统用户
sudo useradd --system --home-dir /var/lib/jslwatcher --shell /bin/false jslwatcher

# 创建必要目录
sudo mkdir -p /etc/jslwatcher /var/lib/jslwatcher /var/log/jslwatcher
sudo chown jslwatcher:jslwatcher /var/lib/jslwatcher /var/log/jslwatcher
```

3. **生成默认配置**

```bash
sudo -u jslwatcher jslwatcher -config /etc/jslwatcher/jslwatcher.conf -test
```

## ⚙️ 配置说明

配置文件位于 `/etc/jslwatcher/jslwatcher.conf`，使用 YAML 格式。

### 基本结构

```yaml
# 通用配置
general:
  log_level: "info"          # 日志级别
  buffer_size: 1000          # 事件缓冲区大小
  retry_count: 3             # 连接重试次数（发送失败重试）
  retry_delay: "5s"          # 重试延迟
  max_file_size: "100MB"     # 文件最大监控大小

# 文件监控配置
files:
  - path: "/var/log/nginx/access.log"
    format: "nginx-access"
    paths: ["/logs/access"]   # 要 POST 的 URI 路径
```

> 提示：服务器域名内置为 `https://future.some.im` 与 `https://future.wxside.com`，会对每条 `paths` 同时发送。

### 配置字段详解

#### general 配置

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `log_level` | string | "info" | 日志级别: debug, info, warn, error |
| `buffer_size` | int | 1000 | 内部事件缓冲区大小 |
| `retry_count` | int | 3 | 发送失败重试次数 |
| `retry_delay` | string | "5s" | 重试间隔时间 |
| `max_file_size` | string | "100MB" | 单个文件最大监控大小 |

#### files 配置

| 字段 | 类型 | 必需 | 说明 |
|------|------|------|------|
| `path` | string | ✓ | 要监控的文件路径 |
| `format` | string | ✓ | 日志格式 (见下方支持列表) |
| `paths` | array | ✓ | 要发送到的 URI 路径列表（如 `/events/app1`） |

### 支持的日志格式

#### 1. `nginx-access` - Nginx 访问日志

支持标准的 Nginx combined 格式：

```
log_format combined '$remote_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent"';
```

**解析字段**:
- `remote_ip`: 客户端 IP
- `method`: HTTP 方法
- `url`: 请求 URL
- `status_code`: HTTP 状态码
- `size`: 响应大小
- `user_agent`: 用户代理
- `referrer`: 引用页面

#### 2. `nginx-error` - Nginx 错误日志

支持标准的 Nginx 错误日志格式：

```
2023/12/01 10:30:45 [error] 1234#0: *1 connect() failed (111: Connection refused)
```

**解析字段**:
- `level`: 错误级别
- `message`: 错误消息

#### 3. `java-log` - Java 应用日志

支持常见的 logback/log4j 格式：

```
2023-12-01 10:30:45.123 [INFO] com.example.Class - Message content
```

**解析字段**:
- `level`: 日志级别
- `message`: 日志消息
- `extra.logger`: 日志器名称

#### 4. `php-error` - PHP 错误日志

支持标准的 PHP 错误日志格式：

```
[01-Dec-2023 10:30:45 UTC] PHP Fatal error: Message in /path/file.php on line 123
```

**解析字段**:
- `level`: 错误级别
- `message`: 错误消息
- `error`: 完整错误信息
- `extra.file`: 文件路径
- `extra.line`: 行号
- `extra.type`: 错误类型

#### 5. `jsonlines` - JSON Lines 格式

每行一个 JSON 对象的格式。如果是标准的结构化日志，会直接解析；否则会包装成通用格式。

**标准字段** (如果存在会自动识别):
- `timestamp`: 时间戳
- `level`: 日志级别
- `message`: 消息内容

### 配置示例

#### 完整配置示例

```yaml
general:
  log_level: "info"
  buffer_size: 2000
  retry_count: 5
  retry_delay: "10s"
  max_file_size: "500MB"

files:
  # Web 服务器日志
  - path: "/var/log/nginx/access.log"
    format: "nginx-access"
    paths: ["/logs/web"]

  - path: "/var/log/nginx/error.log"
    format: "nginx-error"
    paths: ["/logs/errors"]

  # 应用日志
  - path: "/var/log/myapp/app.log"
    format: "java-log"
    paths: ["/logs/api"]

  # PHP 应用
  - path: "/var/log/php-fpm/error.log"
    format: "php-error"
    paths: ["/logs/errors"]

  # 自定义 JSON 日志
  - path: "/var/log/myapp/events.jsonl"
    format: "jsonlines"
    paths: ["/events/app1"]
```

#### 最小配置示例

```yaml
general:
  log_level: "info"

files:
  - path: "/var/log/nginx/access.log"
    format: "nginx-access"
    paths: ["/logs/default"]
```

## 🛠️ 使用指南

### 基本命令

```bash
# 启动服务
sudo systemctl start jslwatcher

# 停止服务
sudo systemctl stop jslwatcher

# 重启服务
sudo systemctl restart jslwatcher

# 查看服务状态
sudo systemctl status jslwatcher

# 设置开机自启
sudo systemctl enable jslwatcher

# 取消开机自启
sudo systemctl disable jslwatcher
```

### 日志查看

```bash
# 查看实时日志
sudo journalctl -u jslwatcher -f

# 查看最近的日志
sudo journalctl -u jslwatcher -n 100

# 查看今天的日志
sudo journalctl -u jslwatcher --since today

# 查看错误级别的日志
sudo journalctl -u jslwatcher -p err
```

### 配置测试

```bash
# 测试配置文件是否正确
sudo -u jslwatcher jslwatcher -test

# 使用自定义配置文件测试
sudo -u jslwatcher jslwatcher -config /path/to/config.yaml -test

# 查看版本信息
jslwatcher -version
```

### 故障排除

#### 1. 服务无法启动

```bash
# 检查配置文件语法
sudo -u jslwatcher jslwatcher -test

# 检查文件权限
ls -la /etc/jslwatcher/
ls -la /var/lib/jslwatcher/
ls -la /var/log/jslwatcher/

# 检查用户是否存在
id jslwatcher
```

#### 2. 无法连接到服务器

```bash
# 检查网络连接
telnet your-server-host 8080

# 检查服务器是否运行
curl -I http://your-server-host:8080

# 查看连接日志
sudo journalctl -u jslwatcher | grep -i connect
```

#### 3. 文件监控不工作

```bash
# 检查文件是否存在
ls -la /var/log/nginx/access.log

# 检查文件权限
sudo -u jslwatcher cat /var/log/nginx/access.log

# 手动测试文件监控
sudo -u jslwatcher jslwatcher -config /etc/jslwatcher/jslwatcher.conf
```

## 📋 系统要求

### 运行环境

- **操作系统**: Linux (Ubuntu 18.04+, CentOS 7+, Debian 9+)
- **架构**: x86_64, ARM64, ARM
- **内存**: 最小 64MB，推荐 128MB+
- **磁盘**: 最小 10MB 可用空间

### 系统依赖

- `systemd` (用于服务管理)
- `curl` 或 `wget` (用于安装)
- 网络连接 (用于连接远程日志服务器)

### 权限要求

JSLWatcher 需要以下权限：

- 读取监控的日志文件
- 写入配置目录 `/etc/jslwatcher/`
- 写入数据目录 `/var/lib/jslwatcher/`
- 写入日志目录 `/var/log/jslwatcher/`
- 网络连接权限

## 🔧 高级配置

### 自定义日志格式

如果需要支持自定义日志格式，可以：

1. **使用 jsonlines 格式**: 将日志转换为 JSON Lines 格式
2. **修改现有解析器**: 在源码中扩展解析器
3. **预处理日志**: 使用其他工具预处理后再监控

### 性能调优

#### 内存优化

```yaml
general:
  buffer_size: 500  # 减少缓冲区大小
  max_file_size: "50MB"  # 限制文件大小
```

#### 网络优化

```yaml
general:
  retry_count: 1     # 减少重试次数
  retry_delay: "1s"  # 减少重试延迟
```

### 多实例部署

可以在同一台服务器上运行多个 JSLWatcher 实例：

```bash
# 创建额外的配置目录
sudo mkdir -p /etc/jslwatcher-app1

# 复制并修改配置文件
sudo cp /etc/jslwatcher/jslwatcher.conf /etc/jslwatcher-app1/

# 创建额外的 systemd 服务
sudo cp /etc/systemd/system/jslwatcher.service /etc/systemd/system/jslwatcher-app1.service

# 修改服务文件中的配置路径
sudo sed -i 's|/etc/jslwatcher/jslwatcher.conf|/etc/jslwatcher-app1/jslwatcher.conf|' /etc/systemd/system/jslwatcher-app1.service
```

## 🔄 升级指南

### 自动升级

使用安装脚本可以自动升级到最新版本：

```bash
curl -fsSL https://raw.githubusercontent.com/xurenlu/FuturePanel/main/jslwatcher/scripts/install.sh | sudo bash
```

### 手动升级

1. **停止服务**

```bash
sudo systemctl stop jslwatcher
```

2. **备份配置**

```bash
sudo cp -r /etc/jslwatcher /etc/jslwatcher.backup
```

3. **下载新版本**

```bash
# 下载最新版本二进制文件
# (参考安装章节)
```

4. **替换二进制文件**

```bash
sudo mv jslwatcher /usr/local/bin/
sudo chmod +x /usr/local/bin/jslwatcher
```

5. **测试配置**

```bash
sudo -u jslwatcher jslwatcher -test
```

6. **启动服务**

```bash
sudo systemctl start jslwatcher
```

## 🗑️ 卸载

### 使用卸载脚本

```bash
curl -fsSL https://raw.githubusercontent.com/xurenlu/FuturePanel/main/jslwatcher/scripts/install.sh | sudo bash -s uninstall
```

### 手动卸载

```bash
# 停止并禁用服务
sudo systemctl stop jslwatcher
sudo systemctl disable jslwatcher

# 删除服务文件
sudo rm /etc/systemd/system/jslwatcher.service
sudo systemctl daemon-reload

# 删除二进制文件
sudo rm /usr/local/bin/jslwatcher

# 删除配置和数据 (可选)
sudo rm -rf /etc/jslwatcher
sudo rm -rf /var/lib/jslwatcher
sudo rm -rf /var/log/jslwatcher

# 删除用户 (可选)
sudo userdel jslwatcher
```

## 📖 API 说明（发送端）

- 发送协议：`HTTP POST https://{future.some.im|future.wxside.com}{path}`
- Header：`Content-Type: application/json`
- Body：解析后的单条日志 JSON（参考解析器输出）

## 🤝 贡献指南

我们欢迎任何形式的贡献！

### 报告问题

请在 [GitHub Issues](https://github.com/xurenlu/FuturePanel/issues) 中报告：

- Bug 报告
- 功能请求
- 文档改进建议

### 提交代码

1. Fork 项目
2. 创建功能分支
3. 提交更改
4. 创建 Pull Request

### 开发环境设置

```bash
# 克隆项目
git clone https://github.com/xurenlu/FuturePanel.git
cd FuturePanel/jslwatcher

# 安装依赖
go mod download

# 运行测试
go test ./...

# 构建
go build -o jslwatcher ./cmd/jslwatcher
```

## 📄 许可证

本项目基于 MIT 许可证开源 - 查看 [LICENSE](../LICENSE) 文件了解详情。

## 🙏 致谢

感谢以下开源项目：

- [fsnotify](https://github.com/fsnotify/fsnotify) - 文件系统监控
- [gorilla/websocket](https://github.com/gorilla/websocket) - WebSocket 客户端
- [go-yaml](https://gopkg.in/yaml.v3) - YAML 解析

---

如果您觉得 JSLWatcher 有用，请给我们一个 ⭐ Star！
