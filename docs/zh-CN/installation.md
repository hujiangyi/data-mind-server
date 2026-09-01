# 安装说明

安装脚本用于把 MCP 客户端连接到已有的 DataMind Go 服务，不会创建或替换
MCP 凭据。

如果 Go 服务启用了邮件发送能力，请先在 Go 网页中使用真实邮箱注册。服务
会把 MCP 安装参数发送到该邮箱，不会放入注册接口响应。已有私有化部署也
可以由管理员直接签发 MCP 凭据对。

必填参数：

- `--tool`
- `--api-base`
- `--credential`
- `--master-key`

支持的工具：

`claude-desktop`、`claude-code`、`cursor`、`vscode`、`opencode` 和
`continue`。

安装脚本下载固定版本的 MCP Release 资产，写入原有 MCP 环境变量，并向
Go 服务标记凭据已使用。它不会写入云端 API Key。

安装完成后，在 Go 服务侧单独配置：

```bash
datamind cloud auth add --name free --key "$DATAMIND_FREE_KEY"
datamind cloud auth use --name free
```

## Windows Go 服务

Windows 不使用原生 Go 可执行文件。请使用 Docker Desktop 的 Linux 容器和
专用安装脚本：

```powershell
irm https://raw.githubusercontent.com/hujiangyi/data-mind-server/main/install/install-go.ps1 | iex
```

脚本会下载对应架构的 Linux Docker 分发包，询问 DataMind Cloud API Key，
并在 `http://127.0.0.1:3001` 启动服务。升级和数据管理请参考
[Windows Docker](windows-docker.md)。

## Linux Go 服务

Linux 服务器可以将已经编译好的 Go 服务安装为 systemd 服务：

```bash
{ curl -fsSL --connect-timeout 8 https://raw.githubusercontent.com/hujiangyi/data-mind-server/main/install/install-go.sh ||
  curl -fsSL --connect-timeout 8 https://gitee.com/hujiangyi/data-mind-server/raw/main/install/install-go.sh; } |
  sudo DATAMIND_GO_VERSION=v0.1.2 bash
```

脚本支持 Linux AMD64 和 ARM64，会校验 Release 文件、询问 DataMind
Cloud API Key，并创建 `datamind-go.service`，在 `127.0.0.1:3001` 启动服务。
脚本不会修改 Nginx 配置。

远程部署时，建议在执行前设置 MCP 用户实际访问的 Go 地址：

```bash
export DAAS_MCP_PUBLIC_API_BASE=https://go.example.com
export DAAS_MCP_SETUP_BASE_URL=https://go.example.com
```

源选择变量和镜像同步方式请参考[Release 镜像](release-mirrors.md)。

## 相关说明

- [云端 API Key](api-key.md)
- [MCP 与云端协议边界](protocol.md)
- [Nginx 部署](nginx.md)
- [故障排查](troubleshooting.md)
