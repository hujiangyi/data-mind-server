# Windows Docker 安装

Go 服务不发布 Windows 原生可执行文件。Windows 用户使用 Docker Desktop
的 Linux 容器运行已经编译好的 Linux Go 服务。

## 安装要求

- 已安装并启动 Docker Desktop。
- Docker Desktop 使用 Linux Containers 模式。
- 可以执行 `docker compose`。
- Windows 主机架构为 AMD64 或 ARM64。
- 交互式安装不要求提前获得 DataMind Cloud API Key；安装器可以代为注册
  免费账号。自动化安装时需要通过环境变量提供已有 Key。

在 PowerShell 中执行：

```powershell
irm https://raw.githubusercontent.com/hujiangyi/data-mind-server/main/install/install-go.ps1 | iex
```

安装脚本会自动选择对应的 Linux 分发包：

```text
Windows AMD64 -> Linux AMD64
Windows ARM64 -> Linux ARM64
```

脚本下载的版本化 Docker 分发包包含已经编译好的 Linux Go 二进制、
runtime Dockerfile、Compose 文件、配置模板和数据库迁移文件。安装器会先
检查 Docker、外部网络和端口，再开始下载。如果没有现成的 DataMind Cloud
API Key，会引导填写真实邮箱和 Cloud 登录密码，自动注册免费账号并取得
Key；已注册邮箱会验证密码并签发新的 Key。密码输入一次且可见。安装器
启动容器后会等待容器健康状态、本机端口和 Cloud AI 欢迎语检查全部通过。

默认访问地址：

```text
http://127.0.0.1:3001
```

安装指定版本：

```powershell
& .\install-go.ps1 -Version v0.1.3
```

安装器默认先探测 Gitee，再探测 GitHub。需要指定源时可以执行：

```powershell
& .\install-go.ps1 -Version v0.1.3 -ReleaseSource gitee
```

也可以使用环境变量 `DATAMIND_RELEASE_SOURCE` 和
`DATAMIND_RELEASE_BASE` 指定源或私有镜像。

Windows 用户不需要安装 Go、MinGW，也不需要 Windows 原生 Go 二进制。

## 数据和升级

运行数据保存于：

```text
%LOCALAPPDATA%\DataMind\data
```

配置和 DataMind API Key 也保存在安装目录中。新取得的 Key 会在安装过程中
显示一次，并提示保存位置。升级时只替换版本化二进制和 Docker 运行文件，
保留本地配置和 SQLite 数据。

停止并删除容器，但保留数据：

```powershell
& .\uninstall-go.ps1
```

停止并删除容器及本地数据：

```powershell
& .\uninstall-go.ps1 -PurgeData
```

Docker 容器继续使用与 Linux 原生安装相同的 Go 到 Cloud AI API 契约。
