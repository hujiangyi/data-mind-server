# DataMind Server

DataMind Server 是 DataMind Go/Vue 数据中台服务的公开发行版和部署文档
仓库。它面向有数据中台需求的中小团队和企业，提供已经编译好的服务端
程序、Vue 管理页面、Docker 运行包、安装脚本和 Nginx 部署模板。

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
- Agnes 等上游提供商的原始 Key 只由 Cloud 服务内部管理，不进入服务端
  Release、浏览器或用户配置；
- 服务端可以部署在企业自己的 Linux 服务器或 Docker 环境中。

## 公开发行版包含什么

- Linux AMD64 和 ARM64 安装脚本；
- macOS AMD64 和 ARM64 Go 服务及 CLI 二进制；
- Linux AMD64 和 ARM64 Go 服务及 CLI 二进制；
- Windows Docker Desktop 使用的 Linux Docker 分发包；
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
  sudo DATAMIND_GO_VERSION=v0.1.2 bash
```

脚本会根据服务器架构选择 Linux AMD64 或 ARM64，探测 Gitee 和 GitHub
Release 镜像，询问 DataMind Cloud API Key，并创建 `datamind-go.service`。
服务默认监听 `127.0.0.1:3001`，同时提供 Vue 网站和服务端 API。

### Windows

Windows 不发布原生 Go 可执行文件。请先安装并启动 Docker Desktop，然后在
PowerShell 中执行：

```powershell
irm https://raw.githubusercontent.com/hujiangyi/data-mind-server/main/install/install-go.ps1 | iex
```

脚本会下载已经编译好的 Linux Docker 分发包，默认在本机提供：

```text
http://127.0.0.1:3001
```

### Nginx 和 HTTPS

生产环境建议使用 HTTPS 域名反向代理到 Go 服务。参考：

- [Nginx 部署](docs/zh-CN/nginx.md)
- [Windows Docker](docs/zh-CN/windows-docker.md)
- [Release 镜像](docs/zh-CN/release-mirrors.md)

## 服务端配置

服务端访问 Cloud AI 中转至少需要：

```text
DATAMIND_CLOUD_API_BASE
DATAMIND_CLOUD_API_KEY
```

安装脚本会保存本地运行所需的配置，并在需要时生成服务端运行密钥。
Cloud API Key 只用于 Go 服务访问 Cloud，不要放入浏览器代码、公开仓库
或普通用户的客户端配置。

## 发布说明

服务端 Release 资产由私有源码仓库本地构建后手动上传。本仓库不运行跨
仓库 GitHub Actions，也不保存发布 Token。

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
