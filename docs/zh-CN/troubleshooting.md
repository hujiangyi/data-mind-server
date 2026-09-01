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
