# 云端 API Key

DataMind Cloud API Key 是 Go 服务访问 DataMind Cloud AI 中转的服务端
凭据。它与数据库凭据相互独立，不能写入浏览器代码、公开仓库或用户本地
AI 工具的配置。

交互式安装器可以直接收集邮箱和 Cloud 登录密码，调用托管 Cloud 的注册
接口并签发免费 Key，因此普通用户不需要先打开注册页面。也可以访问托管
网站手工注册。会员开通成功后会签发具有对应使用权益的会员 Key。免费
Key 会继续保留，会员 Key 有效时 Go CLI 默认优先使用会员 Key。

注册时请使用真实、可以正常收信的邮箱和至少 8 位密码。邮箱用于后续
Cloud 登录和账号管理；注册密码不能代替 API Key。Agnes 上游 `cpk_...`
Key 属于 Cloud 内部资源，不能直接配置到 Go 服务。

## 配置 Key profile

可以使用 DataMind CLI 保存本地 Key profile：

```bash
datamind cloud auth add --name free --key '<free-key>'
datamind cloud auth add --name member --key '<member-key>'
datamind cloud auth use --name member
datamind cloud auth list
datamind cloud plan --base-url https://dm.iter-self.top
datamind cloud usage --base-url https://dm.iter-self.top
```

没有会员权益时使用免费 profile：

```bash
datamind cloud auth use --name free
```

`auth list` 只输出脱敏 Key。配置文件应只允许服务账号或当前用户读取。
怀疑泄露时应立即轮换，并且不要把新 Key 放入 Release 压缩包、Docker
镜像、浏览器存储或 Issue。

私有化部署可以把托管 Cloud 地址替换为运营方自己的 Cloud 地址。原则上
只有 Go 服务保存和使用 Cloud API Key。
