# Security Policy

Do not report credential leaks or exploitable vulnerabilities in public
issues. Send a private report to the project security contact configured in
the GitHub repository.

Never include complete values for:

- Cloud API keys
- JWTs or authorization headers
- database passwords or customer data

Cloud API keys belong to the server-side Cloud connection. They must not be
copied into browser code, public release files, or user-facing configuration.

简体中文：请通过 GitHub 仓库配置的私密安全联系方式报告漏洞，不要在公开
Issue 中提交完整凭据、云端 API Key、JWT、数据库密码或客户数据。
