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
runtime Dockerfile、Compose 文件、配置模板和数据库迁移文件。随后脚本
如果没有现成的 DataMind Cloud API Key，会引导填写真实邮箱和 Cloud 登录
密码，自动注册免费账号并取得 Key，然后启动本地容器。也可以在菜单中
选择输入已有 Key。

默认访问地址：

```text
http://127.0.0.1:3001
```

安装指定版本：

```powershell
& .\install-go.ps1 -Version v0.1.2
```

安装器默认先探测 Gitee，再探测 GitHub。需要指定源时可以执行：

```powershell
& .\install-go.ps1 -Version v0.1.2 -ReleaseSource gitee
```

也可以使用环境变量 `DATAMIND_RELEASE_SOURCE` 和
`DATAMIND_RELEASE_BASE` 指定源或私有镜像。

Windows 用户不需要安装 Go、MinGW，也不需要 Windows 原生 Go 二进制。

## 数据和升级

运行数据保存于：

```text
%LOCALAPPDATA%\DataMind\data
```

配置和 DataMind API Key 也保存在安装目录中。升级时只替换版本化二进制
和 Docker 运行文件，保留本地配置和 SQLite 数据。

停止并删除容器，但保留数据：

```powershell
& .\uninstall-go.ps1
```

停止并删除容器及本地数据：

```powershell
& .\uninstall-go.ps1 -PurgeData
```

Docker 容器继续使用与 Linux 原生安装相同的 Go 到 Cloud API 契约。
