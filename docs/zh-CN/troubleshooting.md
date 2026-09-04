# 故障排查

## 服务没有启动

先检查 systemd 服务状态和最近日志：

```bash
sudo systemctl status datamind-go.service
sudo journalctl -u datamind-go.service -n 100 --no-pager
```

如果使用 Docker，检查容器和 Compose 日志：

```bash
docker ps -a
docker compose logs --tail=100
```

确认服务器架构正确，`3001` 端口没有被其他程序占用，并确认安装目录
对服务账号可读。

## 网站或 API 无法访问

先检查本机健康检查接口：

```bash
curl -i http://127.0.0.1:3001/health
```

如果本机接口正常而域名无法访问，请检查 Nginx 上游、DNS 记录、防火墙、
TLS 证书和域名配置。Nginx 应该代理到 `127.0.0.1:3001`，不要指向
Cloud 服务使用的端口。

## 安装器网络检查失败

安装器会在下载二进制和注册账号前检查 Cloud AI 地址，并检查可用的
Release 源。如果检查失败，脚本会直接退出，不会继续等待。

安装器会先尝试系统默认网络路径，失败后自动尝试一次直连。先确认服务器
能解析并访问 HTTPS；仍然失败时，再根据网络环境选择直连或代理：

```bash
sudo DATAMIND_CURL_NO_PROXY=1 DATAMIND_GO_VERSION=v0.1.8 bash ./install/install-go.sh
```

```bash
sudo DATAMIND_CURL_PROXY=http://proxy.example.com:8080 \
  DATAMIND_GO_VERSION=v0.1.8 bash ./install/install-go.sh
```

如果 Cloud AI 检查通过但 Release 源不可用，可以设置
`DATAMIND_RELEASE_SOURCE=gitee` 或 `DATAMIND_RELEASE_SOURCE=github` 强制
选择源；仍然失败时检查服务器防火墙、DNS、代理和出站 `443` 端口。

## Release 缺少升级工具

如果看到以下错误：

```text
错误：Release 缺少 bin/datamind-upgrade，拒绝执行未带升级工具的 Release
```

说明当前下载到的 Release 压缩包是旧格式或上传不完整。先不要删除当前
安装，也不要手工覆盖 `/opt/datamind-go/bin/daas-go`。确认目标 Release
的 Go 压缩包同时包含 `bin/datamind-upgrade`、`migrations/` 和
`migration-manifest.json`，并确认 `checksums.txt` 与实际文件匹配。

GitHub 和 Gitee 必须分别上传同一批完整资产；只更新其中一个源会导致安装
器因网络回退而再次下载旧包。修复 Release 后重新执行安装命令即可，升级
模式会保留数据、配置和 Cloud Key。

## Cloud AI 不可用

执行本地诊断并检查当前 Cloud profile：

```bash
datamind doctor
datamind cloud plan --base-url https://dm.iter-self.top
datamind cloud usage --base-url https://dm.iter-self.top
```

确认 Cloud API 地址可以访问，配置的 API Key 有效，账户仍有可用额度，
并检查会员状态或队列等级是否符合预期。不要把完整 Key 粘贴到日志或
Issue 中。

## 用户没有收到注册邮件

先确认注册时填写的邮箱地址拼写正确，邮箱当前可以正常收信，并检查垃圾
邮件、广告邮件、隔离区以及企业邮箱网关。不同邮箱服务商的拦截策略可能
不同，建议改用另一个真实且可接收邮件的邮箱重新注册或重试。

如果多个有效邮箱都没有收到邮件，再联系服务管理员，并提供注册时间和
脱敏后的邮箱地址。不要把完整凭据、API Key 或客户数据放入公开 Issue。

## 数据源或查询失败

检查数据源地址、端口、数据库名、账号状态、网络白名单和 TLS 要求。
确认服务所在服务器可以独立访问数据库，而不是只验证浏览器网络。
查看服务日志中的脱敏错误、数据源名称、操作类型和请求时间，不要包含
密码或完整客户记录。
