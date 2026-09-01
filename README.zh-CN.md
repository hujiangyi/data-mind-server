# DataMind Server

DataMind Server 是 DataMind Go/Vue 服务的公开发行版和部署文档仓库。

本仓库用于下载和运行已经编译好的服务端产品，包含：

- Linux AMD64 和 ARM64 安装脚本；
- Windows Docker 安装脚本；
- Docker Compose 和运行时模板；
- Nginx 部署示例；
- 服务端 Release、校验文件和兼容性说明；
- 中英文部署文档。

本仓库**不包含**闭源 DataMind Go、Vue 和 Cloud 源代码。服务端二进制由
私有源码仓库构建后手动发布到本仓库的 Release。二进制的使用范围以每个
Release 中附带的 EULA 为准。

## 选择安装方式

### Linux 服务器

安装已经编译好的 Go 服务：

```bash
{ curl -fsSL --connect-timeout 8 https://raw.githubusercontent.com/hujiangyi/data-mind-server/main/install/install-go.sh ||
  curl -fsSL --connect-timeout 8 https://gitee.com/hujiangyi/data-mind-server/raw/main/install/install-go.sh; } |
  sudo DATAMIND_GO_VERSION=v0.1.1 bash
```

脚本会根据服务器架构选择 Linux AMD64 或 ARM64，探测 Gitee 和 GitHub
Release 镜像，询问 DataMind Cloud API Key，并创建 `datamind-go.service`。

### Windows

Windows 不使用原生 Go 二进制。请先安装并启动 Docker Desktop，然后在
PowerShell 中执行：

```powershell
irm https://raw.githubusercontent.com/hujiangyi/data-mind-server/main/install/install-go.ps1 | iex
```

脚本会运行已经编译好的 Linux Go Docker 发行包，默认在本机提供：

```text
http://127.0.0.1:3001
```

### Nginx 和 HTTPS

生产环境建议使用 HTTPS 域名反向代理到 Go 服务。参考：

- [Nginx 部署](docs/zh-CN/nginx.md)
- [Windows Docker](docs/zh-CN/windows-docker.md)
- [Release 镜像](docs/zh-CN/release-mirrors.md)

## 服务端配置

服务端需要单独配置：

```text
DATAMIND_CLOUD_API_BASE
DATAMIND_CLOUD_API_KEY
DAAS_MCP_MASTER_KEY
DAAS_MCP_SETUP_BASE_URL
DAAS_MCP_PUBLIC_API_BASE
```

其中：

- `DATAMIND_CLOUD_API_BASE` 和 `DATAMIND_CLOUD_API_KEY` 用于 Go 服务访问
  DataMind Cloud；
- `DAAS_MCP_SETUP_BASE_URL` 是用户邮件中的安装配置页面地址；
- `DAAS_MCP_PUBLIC_API_BASE` 是 MCP 客户端实际连接的 Go 服务地址；
- Agnes API Key 只由 Cloud 服务内部管理，不属于服务端安装参数。

远程部署时请在安装前设置公开 Go 地址，例如：

```bash
DAAS_MCP_PUBLIC_API_BASE=https://go.example.com \
DAAS_MCP_SETUP_BASE_URL=https://go.example.com \
sudo -E bash install/install-go.sh
```

## 发布说明

服务端 Release 资产由私有源码仓库构建后手动上传。本仓库不运行跨仓库
GitHub Actions，也不保存任何发布 Token。

发布前必须验证：

```text
Release 资产存在
checksums.txt 校验正确
Linux AMD64 安装成功
Linux ARM64 安装成功
Windows Docker 安装成功
Go 健康检查成功
Vue 首页可以访问
MCP 可以连接 Go 服务
```

## 许可证

本仓库中的安装脚本、部署模板和公开文档采用 Apache License 2.0。
Release 中的服务端二进制不以开源源码形式发布，具体使用条款以对应
Release 附带的 EULA 为准。

English documentation: [README.md](README.md)
