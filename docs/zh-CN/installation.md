# 安装说明

本文说明如何安装已经编译好的 DataMind Go/Vue 服务。服务会同时提供
Vue 管理页面和服务端 API。

## 安装要求

- Linux AMD64 或 ARM64，用于原生 systemd 安装；或者 Windows + Docker
  Desktop Linux 容器；
- 具备安装系统服务或运行 Docker 的权限；
- 交互式安装时不需要提前准备 DataMind Cloud API Key，安装器可以代为注册
  免费账号；非交互安装时需要通过环境变量提供已有 Key；
- 服务器有可用端口，默认使用 `3001`。

## Linux 服务器

使用 root 执行一键命令。脚本会先检查系统权限、架构、必要依赖、外部网络、
可用下载源和 `3001` 端口，再下载并校验匹配的 Release，最后创建
`datamind-go.service`。正常输出只显示检查是否通过，不显示 Cloud 内部
地址或上游 HTTP 状态。如果没有现成的 DataMind Cloud API Key，安装器会
引导填写邮箱和 Cloud 登录密码，自动注册免费账号并取得 Key：

```bash
{ curl -fsSL --connect-timeout 8 https://raw.githubusercontent.com/hujiangyi/data-mind-server/main/install/install-go.sh ||
  curl -fsSL --connect-timeout 8 https://gitee.com/hujiangyi/data-mind-server/raw/main/install/install-go.sh; } |
  sudo DATAMIND_GO_VERSION=v0.1.3 bash
```

服务默认监听 `0.0.0.0:3001`，同时提供 Vue 网站和服务端 API。安装前会
检查端口是否已被占用，启动后会等待服务进程、监听地址和健康接口全部通过。

需要指定 Release 下载源时，可以设置：

```bash
export DATAMIND_RELEASE_SOURCE=gitee
```

支持 `github`、`gitee` 和 `auto`。默认 `auto` 会检查实际网络可达性，
选择可用的 Release 下载源。

安装器默认先使用系统网络路径；如果该路径失败，会自动尝试一次直连。
如果服务器配置了无法访问外网的代理，也可以显式指定直连：

```bash
sudo DATAMIND_CURL_NO_PROXY=1 DATAMIND_GO_VERSION=v0.1.3 bash ./install/install-go.sh
```

如果服务器必须经过指定代理，可以设置：

```bash
sudo DATAMIND_CURL_PROXY=http://proxy.example.com:8080 \
  DATAMIND_GO_VERSION=v0.1.3 bash ./install/install-go.sh
```

网络检查失败时，脚本会在下载二进制前直接退出，不会继续等待后续安装。

## Windows 使用 Docker Desktop

Windows 不使用原生 Go 可执行文件。请安装并启动 Docker Desktop，并确保
使用 Linux Containers 模式，然后在 PowerShell 中执行：

```powershell
irm https://raw.githubusercontent.com/hujiangyi/data-mind-server/main/install/install-go.ps1 | iex
```

安装脚本会检查 Docker Desktop、网络和端口，选择对应的 Linux Docker
分发包。如果没有现成的 Cloud API Key，会引导填写邮箱和 Cloud 登录密码，
自动注册免费账号并启动。容器端口默认绑定 `0.0.0.0:3001`，本机访问地址为：

```text
http://127.0.0.1:3001
```

安装指定版本：

```powershell
& .\install-go.ps1 -Version v0.1.3
```

Windows 安装不需要 Go、MinGW 或 Windows 原生 Go 构建环境。

## Web 管理账号和首次登录

安装完成后，请打开安装器显示的 Web 管理入口。全新安装的内置管理员
账号为：

```text
用户名：admin
初始密码：123456
```

第一次登录并不代表已经完成账号启用。系统会自动跳转到首次改密页面，
必须设置一个 8～16 位的正式密码，完成后才能进入业务管理页面。

管理员创建的账号以及管理员重置密码后的账号，也统一使用固定初始密码
`123456`，用户第一次登录必须改成自己的 8～16 位正式密码。普通用户
自助注册时可以设置登录初始密码，但第一次登录同样必须重新设置正式密码。
改密完成前，受保护的业务接口都会被拒绝。

管理员在网页中重置账号：

**用户管理 → 编辑用户 → 重置初始密码**

重置后账号恢复为 `123456`，并重新进入首次登录改密状态。

如果管理员无法进入网页，也可以在服务器命令行执行：

```bash
sudo /opt/datamind-go/bin/daas-go \
  -config /opt/datamind-go/configs/config.yaml \
  -reset-password \
  -username admin
```

直接在服务器命令行给账号设置正式密码：

```bash
sudo /opt/datamind-go/bin/daas-go \
  -config /opt/datamind-go/configs/config.yaml \
  -change-password \
  -username admin
```

命令行设置的正式密码必须为 8～16 位。以上命令直接更新 SQLite 账号
数据，不需要重启服务。Web 管理账号密码与 `DATAMIND_CLOUD_API_KEY`
是两套不同信息，不能相互替代。

## Cloud 注册和配置

Go 服务访问 Cloud AI 中转至少需要以下服务端配置：

```text
DATAMIND_CLOUD_API_BASE
DATAMIND_CLOUD_API_KEY
```

### 推荐：安装器自动注册

第一次运行交互式安装器时，如果没有检测到 Key，选择：

```text
1) 自动注册免费账号并生成 Key（推荐）
```

然后填写真实、可收信的邮箱和至少 8 位 Cloud 登录密码，密码只输入一次且
按用户要求采用可见输入。安装器会调用 Cloud 注册接口，取得
`dm_free_...` Key，并以受限权限写入本地配置。新取得的 Key 会在安装过程
中显示一次，并提示服务端保存位置。

如果邮箱已经注册，安装器会使用刚才输入的密码验证账号并签发新的 Key；
密码不匹配时重新输入即可。也可以先访问 `https://dm.iter-self.top/` 完成
注册，再把网页显示的 Key 粘贴到安装器。注册密码仅用于 Cloud 登录，不能
代替 API Key；其他 Cloud 服务凭据属于内部部署信息，也不能作为 DataMind
Cloud API Key。

### 自动化安装

非交互安装需要由管理员预先提供：

```text
DATAMIND_CLOUD_API_BASE
DATAMIND_CLOUD_API_KEY
```

安装脚本会在不回显 Key 的情况下保存本地配置。不要把 Key 写入浏览器
代码、Release 压缩包、Docker 镜像或公开 Issue。

## 公网域名和 Nginx

服务可以直接使用 `3001` 端口运行。启动成功后安装器会使用当前 Key 生成一段
Cloud AI 欢迎语，确认 AI 能力可达后才报告安装成功。如果需要公网域名和
HTTPS，请让 Nginx 将域名代理到 `127.0.0.1:3001`：

```text
https://data.example.com -> Nginx :443 -> DataMind Server :3001
```

反向代理模板请参考 [Nginx 部署](nginx.md)。如果不希望直接暴露 `3001`，
可在安装前设置 `DATAMIND_BIND_ADDRESS=127.0.0.1`，让 Nginx 作为唯一公网
入口。

## 数据和升级

安装脚本会把运行配置和本地 SQLite 数据保存在版本化二进制之外。使用
新的 Release 重新执行安装脚本时，只更新服务程序，保留本地数据目录。

Linux 停止并移除服务：

```bash
{ curl -fsSL https://raw.githubusercontent.com/hujiangyi/data-mind-server/main/install/uninstall-go.sh ||
  curl -fsSL https://gitee.com/hujiangyi/data-mind-server/raw/main/install/uninstall-go.sh; } |
  sudo bash
```

Windows 使用对应的 `uninstall-go.ps1` 脚本。未使用清理数据选项时，只会
移除容器并保留本地数据。

## 相关说明

- [云端 API Key](api-key.md)
- [Nginx 部署](nginx.md)
- [Release 镜像](release-mirrors.md)
- [故障排查](troubleshooting.md)
- [管理员操作指南](admin-guide.md)
