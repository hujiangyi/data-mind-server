# Nginx 部署

Nginx 是可选组件。Go 服务已经内置 Vue 页面，可以直接监听 `3001` 同时
提供网站和 API。需要绑定公网域名、终止 TLS、保留访问日志或增加反向代理
边界时，再使用 Nginx。

当前托管 Cloud 是 `ny` 上独立运行的 Node 服务：

```text
dm.iter-self.top -> Nginx :80 -> DataMind Cloud Node :3456
```

这与用户私有化部署的 Go 服务是两条独立链路：

```text
私有域名 -> Nginx :80/443 -> DataMind Go :3001
```

Nginx 应负责：

- 终止 TLS；
- 将 Vue 页面和 Go API 请求都代理到 `127.0.0.1:3001`；
- 保留 Host、客户端 IP 和转发协议请求头；
- 关闭 AI 流式接口的代理缓冲；
- 为 AI 请求设置较长读取超时；
- 暴露 `/health` 作为部署检查入口。

以 `deploy/nginx/datamind.conf` 为基础替换域名、上游地址和证书路径。
Go 服务只允许监听容器网络或本机回环地址。不要把这份 Go 配置指向
托管 Cloud Node 的端口；`ny` 上的 Cloud Node 使用独立的 Nginx 站点配置。
