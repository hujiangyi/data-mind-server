# 安装说明

本文说明如何安装已经编译好的 DataMind Go/Vue 服务。服务会同时提供
Vue 管理页面和服务端 API。

## 安装要求

- Linux AMD64 或 ARM64，用于原生 systemd 安装；或者 Windows + Docker
  Desktop Linux 容器；
- 具备安装系统服务或运行 Docker 的权限；
- 已获得用于 Go 服务访问 Cloud AI 中转的 DataMind Cloud API Key；
- 服务器有可用端口，默认使用 `3001`。

## Linux 服务器

使用 root 执行一键命令。脚本会选择匹配的架构，探测 Gitee 和 GitHub
Release 镜像，校验下载文件，询问 DataMind Cloud API Key，并创建
`datamind-go.service`：

```bash
{ curl -fsSL --connect-timeout 8 https://raw.githubusercontent.com/hujiangyi/data-mind-server/main/install/install-go.sh ||
  curl -fsSL --connect-timeout 8 https://gitee.com/hujiangyi/data-mind-server/raw/main/install/install-go.sh; } |
  sudo DATAMIND_GO_VERSION=v0.1.2 bash
```

服务默认监听 `127.0.0.1:3001`，同时提供 Vue 网站和服务端 API。

需要指定 Release 下载源时，可以设置：

```bash
export DATAMIND_RELEASE_SOURCE=gitee
```

支持 `github`、`gitee` 和 `auto`。默认 `auto` 会检查实际网络可达性，
选择可用的 Release 下载源。

## Windows 使用 Docker Desktop

Windows 不使用原生 Go 可执行文件。请安装并启动 Docker Desktop，并确保
使用 Linux Containers 模式，然后在 PowerShell 中执行：

```powershell
irm https://raw.githubusercontent.com/hujiangyi/data-mind-server/main/install/install-go.ps1 | iex
```

安装脚本会选择对应的 Linux Docker 分发包，询问 Cloud API Key，并启动：

```text
http://127.0.0.1:3001
```

安装指定版本：

```powershell
& .\install-go.ps1 -Version v0.1.2
```

Windows 安装不需要 Go、MinGW 或 Windows 原生 Go 构建环境。

## Cloud 配置

Go 服务访问 Cloud AI 中转至少需要以下服务端配置：

```text
DATAMIND_CLOUD_API_BASE
DATAMIND_CLOUD_API_KEY
```

安装脚本会在不回显 Key 的情况下询问输入，并以受限权限保存本地配置。
不要把 Key 写入浏览器代码、Release 压缩包、Docker 镜像或公开 Issue。

## 公网域名和 Nginx

服务可以直接使用 `3001` 端口运行。如果需要公网域名和 HTTPS，请让
Nginx 将域名代理到 `127.0.0.1:3001`：

```text
https://data.example.com -> Nginx :443 -> DataMind Server :3001
```

反向代理模板请参考 [Nginx 部署](nginx.md)。使用 Nginx 时，建议 Go
服务只监听本机回环地址或私有容器网络。

## 数据和升级

安装脚本会把运行配置和本地 SQLite 数据保存在版本化二进制之外。使用
新的 Release 重新执行安装脚本时，只更新服务程序，保留本地数据目录。

Linux 停止并移除服务：

```bash
sudo systemctl disable --now datamind-go.service
sudo rm -f /etc/systemd/system/datamind-go.service
sudo systemctl daemon-reload
```

Windows 使用对应的 `uninstall-go.ps1` 脚本。未使用清理数据选项时，只会
移除容器并保留本地数据。

## 相关说明

- [云端 API Key](api-key.md)
- [Nginx 部署](nginx.md)
- [Release 镜像](release-mirrors.md)
- [故障排查](troubleshooting.md)
