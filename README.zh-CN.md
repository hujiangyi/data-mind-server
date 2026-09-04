# DataMind Server

DataMind Server 是 DataMind 数据中台服务的公开发行版和部署文档
仓库。它面向有数据中台需求的中小团队和企业，提供已经编译好的服务端
程序、管理页面、Docker 运行包、安装脚本和 Nginx 部署模板。

本仓库不包含闭源 DataMind Go、Vue 和 Cloud 源代码。服务端二进制由私有
源码仓库构建后手动发布到 Release，具体使用范围以每个 Release 附带的
EULA 为准。

## DataMind 解决什么问题

很多团队的业务数据分散在 CRM、订单、库存、财务、客服、项目管理和
内部运营系统中。数据可能同时存在于多个 MySQL、PostgreSQL 或其他业务
数据库里，团队通常会遇到以下问题：

- 数据分散在不同系统中，跨系统对照和汇总依赖人工导出；
- 同一客户、订单、商品或项目在不同系统中的信息难以关联；
- 直接把数据库账号交给 AI，权限范围过大，容易泄露无关数据或执行
  超出业务范围的查询；
- 不给 AI 数据权限，又无法充分利用 AI 做数据检索、结构理解、经营分析
  和日常数据管理；
- 管理员需要按照部门、岗位、业务线、数据源和业务范围分配权限，并且
  能够追踪数据访问行为。

DataMind 的定位是**受控的数据中台和 AI 数据访问边界**。它不要求团队
一开始就把所有业务数据搬迁到一个新数据库，而是通过统一的服务接入
现有数据源，集中管理数据连接、元数据、查询入口、用户权限和审计结果。

## 适用场景

### 中小团队的统一数据入口

当销售、运营、仓库和财务分别使用不同系统时，团队可以把这些数据源
接入 DataMind，使用一个管理页面查看连接状态、数据库和表结构，并在
授权范围内进行跨系统的数据整理和查询。

例如，销售负责人可以关联客户和订单数据，运营人员可以查看订单与库存
情况，财务人员可以使用财务数据库进行核对，而每个人只看到自己负责的
业务范围。

### 企业的多系统数据关联管理

对于拥有多个业务系统、多个部门或多个租户的企业，DataMind 可以作为
统一的数据访问层，帮助管理员集中维护数据源和数据权限。业务系统仍可
保留原有数据库和运行方式，DataMind 负责提供统一的访问入口和可执行的
安全边界。

典型的数据关联包括：

- 客户、联系人与销售机会；
- 订单、商品、库存与物流；
- 回款、发票、合同与客户主体；
- 工单、客服记录与产品问题；
- 项目、成员、成本与交付进度。

### AI 辅助数据管理

团队可以让 AI 帮助理解表结构、查找业务数据、生成查询思路、汇总结果
和发现异常，同时把真正的数据访问权限留在 DataMind 服务端。AI 不需要
直接持有生产数据库账号，也不需要拥有整个数据库的管理员权限。

AI 的请求先经过 DataMind 的身份、角色、数据源和业务范围校验，再由
服务端使用受控的数据连接执行。这样可以在“希望 AI 帮忙管理数据”和
“不能把全部数据权限交给 AI”之间取得平衡。

## 核心工作方式

1. **接入现有数据源**：管理员配置业务数据库和数据源连接，不强制改变
   原有系统的存储方式。
2. **统一查看数据结构**：在管理页面中查看数据源、数据库、表和字段等
   元数据，为后续查询和管理提供统一入口。
3. **按角色分配权限**：按照用户、组织、岗位、业务线、数据源、数据库、
   表和业务范围进行分权。
4. **服务端执行查询**：查询由 Go 服务端建立数据连接和执行权限校验，
   而不是把生产数据库账号直接交给 AI 或普通用户。
5. **限制数据范围**：服务端根据当前用户的授权范围处理查询，避免用户
   因为修改客户端参数而访问不属于自己的数据。
6. **保留运行审计**：记录关键的访问结果、状态和运行信息，便于排查、
   复核和企业内部治理。

## 数据安全边界

DataMind 适合以下安全诉求：

- 普通用户只能访问被分配的数据源和业务范围；
- 管理员可以集中维护用户、角色、数据源和授权关系；
- AI 使用的是服务端提供的受控能力，而不是完整数据库超级权限；
- Cloud API Key 只保存在 Go 服务侧，用于服务访问 Cloud AI 中转；
- 服务端可以部署在企业自己的 Linux 服务器或 Docker 环境中。

## 公开发行版包含什么

- Linux AMD64 和 ARM64 安装脚本；
- macOS AMD64 和 ARM64 Go 服务及 CLI 二进制；
- Linux AMD64 和 ARM64 Go 服务及 CLI 二进制；
- Windows Docker Desktop 使用的 Linux Docker 分发包；
- Go 服务端升级工具、完整数据库迁移目录和迁移清单；
- Docker Compose 和运行时模板；
- Nginx 反向代理部署示例；
- Release 校验文件和兼容性说明；
- 中英文安装、部署和故障排查文档。

## 选择安装方式

### Linux 服务器

安装已经编译好的 Go/Vue 服务：

```bash
{ curl -fsSL --connect-timeout 8 https://raw.githubusercontent.com/hujiangyi/data-mind-server/main/install/install-go.sh ||
  curl -fsSL --connect-timeout 8 https://gitee.com/hujiangyi/data-mind-server/raw/main/install/install-go.sh; } |
  sudo DATAMIND_GO_VERSION=v0.1.8 bash
```

脚本会先检查系统依赖、外部网络、可用下载源和 `3001` 端口，再根据服务器
架构选择 Linux AMD64 或 ARM64。正常输出只展示检查是否通过，不显示 Cloud
内部地址或上游 HTTP 细节。
如果没有现成的 DataMind Cloud API Key，脚本会引导填写邮箱和 Cloud
登录密码，自动注册免费账号并取得 Key，然后创建 `datamind-go.service`。
如果邮箱已经注册，输入匹配的 Cloud 密码即可签发一个新的可用 Key。
服务默认监听 `0.0.0.0:3001`，同时提供 Vue 网站和服务端 API。
安装完成后，脚本会同时显示本机回环地址 `http://127.0.0.1:3001` 和服务器
访问地址 `http://{server_ip}:3001`；其中 `{server_ip}` 会优先自动识别，也可以
通过 `DATAMIND_SERVER_IP` 显式指定。

安装器会严格校验 Go 服务端 Release 包，包内必须包含：

```text
bin/daas-go
bin/datamind-upgrade
migrations/
migration-manifest.json
frontend-build.json
configs/config.yaml
VERSION
```

其中 `bin/datamind-upgrade` 负责在切换新服务版本前备份并执行数据库和
配置迁移，`migration-manifest.json` 用于校验迁移文件的完整性。缺少任一
升级资产时，安装器会拒绝继续执行，不会覆盖当前服务。安装器支持更新和
重新安装两种已有安装处理方式；重新安装会清除数据源、子账号、数据权限
和本地审计数据，必须重新配置并明确确认。

### Windows

Windows 不发布原生 Go 可执行文件。请先安装并启动 Docker Desktop，然后在
PowerShell 中执行：

```powershell
irm https://raw.githubusercontent.com/hujiangyi/data-mind-server/main/install/install-go.ps1 | iex
```

脚本会先检查 Cloud AI 网络连接，再下载已经编译好的 Linux Docker 分发包，
默认在本机提供：

```text
http://127.0.0.1:3001
```

容器端口默认绑定 `0.0.0.0:3001`，本机访问仍使用
`http://127.0.0.1:3001`。

### Web 管理账号和首次登录

全新安装时，内置管理员账号为：

```text
用户名：admin
初始密码：123456
```

初始密码是固定的临时密码。第一次登录后，系统会强制进入改密页面，
必须设置一个 8～16 位的正式密码，完成后才能进入管理页面。

管理员创建的员工账号以及管理员执行密码重置后的账号，也统一使用固定
初始密码 `123456`，员工第一次登录必须改成自己的 8～16 位正式密码。
普通用户自助注册时可以设置登录初始密码，但第一次登录同样必须重新设置
正式密码。在完成改密前，服务端受保护的业务接口都会被阻止。

Web 管理账号密码与 Go 服务访问 DataMind Cloud 使用的 API Key 是两套
不同信息，不能相互替代。

DataMind 不会保留或记录用户私有业务数据，请放心使用。完整的数据处理
边界请参阅[隐私协议](docs/zh-CN/privacy-policy.md)。

### Nginx 和 HTTPS

生产环境建议使用 HTTPS 域名反向代理到 Go 服务。参考：

- [Nginx 部署](docs/zh-CN/nginx.md)
- [管理员操作指南](docs/zh-CN/admin-guide.md)
- [Windows Docker](docs/zh-CN/windows-docker.md)
- [Release 镜像](docs/zh-CN/release-mirrors.md)

## 注册 Cloud 账号并安装服务

### 1. 直接运行安装器并自动注册（推荐）

Linux 服务器执行：

```bash
{ curl -fsSL --connect-timeout 8 https://raw.githubusercontent.com/hujiangyi/data-mind-server/main/install/install-go.sh ||
  curl -fsSL --connect-timeout 8 https://gitee.com/hujiangyi/data-mind-server/raw/main/install/install-go.sh; } |
  sudo DATAMIND_GO_VERSION=v0.1.8 bash
```

Windows 用户先安装并启动 Docker Desktop，然后在 PowerShell 执行：

```powershell
irm https://raw.githubusercontent.com/hujiangyi/data-mind-server/main/install/install-go.ps1 | iex
```

首次安装且没有现成 Key 时，脚本会显示以下选择：

```text
1) 自动注册免费账号并生成 Key（推荐）
2) 输入已有 DataMind API Key
3) 退出安装
```

选择 `1` 后，只需填写：

- 一个真实、当前可以正常收信的邮箱地址；
- 一个至少 8 位的 Cloud 登录密码，输入一次即可；安装器按用户要求采用
  可见输入，方便在服务器终端确认。

安装器会通过 Cloud 注册接口自动创建免费账号，取得 `dm_free_...` 形式的
DataMind Cloud API Key，并把它写入服务端受限权限配置。邮箱已经注册时，
安装器会用同一组邮箱和密码完成验证并签发新的 Key，不要求重新注册。
新取得的 Key 会在安装过程中显示一次，并提示保存位置；不要把终端输出分享
给他人。安装器还会等待服务真正进入运行状态，确认端口监听、健康接口和
Cloud AI 欢迎语能力都通过后才报告成功。
安装完成后，服务访问地址为：

```text
http://127.0.0.1:3001
```

邮箱必须真实且可以正常收信，用于后续账号登录和账号管理。注册密码只
用于 Cloud 账号登录，不能代替 API Key。其他 Cloud 服务凭据属于内部部署
信息，不能用于安装 DataMind Server。

### 2. 已有账号或网页注册

如果邮箱已经注册，安装器会使用输入的 Cloud 密码验证账号并取得新的
DataMind API Key。密码不匹配时再重新输入即可。也可以先打开 DataMind
Cloud 网站：

```text
https://dm.iter-self.top/
```

在注册区域填写真实邮箱和至少 8 位密码。注册成功后，网页会显示账号信息、
免费套餐信息以及 `dm_free_...` Key。随后在安装器中选择“输入已有
DataMind API Key”，粘贴 Key。

### 3. 非交互安装时使用环境变量

自动化部署可以提前设置以下变量：

```bash
export DATAMIND_CLOUD_API_BASE=https://dm.iter-self.top/v1
export DATAMIND_CLOUD_API_KEY='dm_free_...'
```

然后执行本地安装脚本：

```bash
sudo -E DATAMIND_GO_VERSION=v0.1.8 bash ./install/install-go.sh
```

环境变量中的 Key 可能进入 Shell 历史或自动化日志。普通安装建议直接
让安装器交互式询问，部署完成后及时清理环境变量。

### 4. 验证套餐和用量

安装完成后，可以使用 Go CLI 检查当前 Key 对应的套餐和用量：

```bash
datamind cloud auth add --name free --key '<your-dm-free-key>'
datamind cloud auth use --name free
datamind cloud auth list
datamind cloud plan --base-url https://dm.iter-self.top
datamind cloud usage --base-url https://dm.iter-self.top
```

`auth list` 只显示脱敏 Key。会员功能启用后，网站会为会员账号提供
独立的会员 Key；届时可以使用另一个 profile 保存并切换，不需要修改
服务程序。

## 发布说明

每个 Release 都包含：

- 对应平台的服务端和 CLI 二进制；
- Windows Docker 分发包；
- `checksums.txt`；
- Release 清单和许可说明。

## 许可证

本仓库中的安装脚本、部署模板和公开文档采用 Apache License 2.0。
Release 中的服务端二进制不以开源源码形式发布，具体使用条款以对应
Release 附带的 EULA 为准。

English documentation: [README.md](README.md)
