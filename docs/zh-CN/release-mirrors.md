# Release 镜像

DataMind 支持 GitHub 和 Gitee 作为 Release 下载源，规划地址为：

```text
GitHub：https://github.com/hujiangyi/data-mind-server
Gitee： https://gitee.com/hujiangyi/data-mind-server
```

两个仓库应保持相同的 `main` 分支、版本标签、Release 资产名称和
`checksums.txt` 内容。Gitee 仓库创建并同步 Release 资产后，Gitee 回退
下载才会生效。GitHub 和 Gitee 必须上传同一批文件，不能只同步 Release
标题或部分资产。

## 源选择

Go 安装器支持：

```text
DATAMIND_RELEASE_SOURCE=auto
DATAMIND_RELEASE_SOURCE=github
DATAMIND_RELEASE_SOURCE=gitee
```

`auto` 会探测 Gitee 和 GitHub 的 Release 地址，并使用第一个可达的源。
默认顺序是 Gitee 优先、GitHub 其次，适合 GitHub 访问较慢或受限的网络。
这里判断的是实际接口可达性，不是根据 IP 地理位置猜测。

使用私有镜像时可以覆盖源地址：

```bash
export DATAMIND_GITHUB_RELEASE_BASE="https://github.com/hujiangyi/data-mind-server/releases/download"
export DATAMIND_GITEE_RELEASE_BASE="https://gitee.com/hujiangyi/data-mind-server/releases/download"
export DATAMIND_RELEASE_BASE="https://mirror.example.com/datamind/releases"
```

`DATAMIND_RELEASE_BASE` 优先级最高，设置后会跳过自动源选择。

## 仓库同步

创建 Gitee 仓库后，可以添加第二个 Git remote，同步公开分支和标签：

```bash
git remote add gitee git@gitee.com:hujiangyi/data-mind-server.git
git push gitee main --tags
```

还需要把对应的完整 Release 资产上传到 Gitee Release。安装器至少需要以下
顶层资产：

```text
datamind-go-linux-amd64.tar.gz
datamind-go-linux-arm64.tar.gz
datamind-docker-linux-amd64.zip
datamind-docker-linux-arm64.zip
checksums.txt
```

GitHub 和 Gitee 的资产字节必须完全一致。同步时不要重新生成压缩包，
否则会导致 `checksums.txt` 失效。每个 `datamind-go-*.tar.gz` 内部还必须
包含：

```text
bin/daas-go
bin/datamind-upgrade
migrations/
migration-manifest.json
configs/config.yaml
VERSION
```

上传后可使用以下命令检查 Gitee 资产：

```bash
mkdir -p /tmp/datamind-v0.1.9-gitee-check
curl -fL -o /tmp/datamind-v0.1.9-gitee-check/server.tar.gz \
  https://gitee.com/hujiangyi/data-mind-server/releases/download/v0.1.9/datamind-go-linux-amd64.tar.gz
tar -tzf /tmp/datamind-v0.1.9-gitee-check/server.tar.gz | \
  grep -E '(^|/)bin/(daas-go|datamind-upgrade)$|migration-manifest.json|^\\./VERSION$|configs/config.yaml'
```

## 一键安装

Linux 一键命令可以先选择可访问的 raw 脚本源：

```bash
{ curl -fsSL --connect-timeout 8 https://raw.githubusercontent.com/hujiangyi/data-mind-server/main/install/install-go.sh ||
  curl -fsSL --connect-timeout 8 https://gitee.com/hujiangyi/data-mind-server/raw/main/install/install-go.sh; } |
  sudo DATAMIND_GO_VERSION=v0.1.9 bash
```

脚本启动后还会独立探测可访问的 Release 下载源。
