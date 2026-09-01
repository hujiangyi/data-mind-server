# Nginx Deployment

Nginx is optional. The Go service embeds the Vue application and can serve the
website and API directly on `3001`. Use Nginx when you need a public domain,
TLS termination, access logs, or an additional reverse-proxy boundary.

The current hosted Cloud service is a separate Node runtime on `ny`:

```text
dm.iter-self.top -> Nginx :80 -> DataMind Cloud Node :3456
```

This is independent of a user's private Go deployment:

```text
private-domain -> Nginx :80/443 -> DataMind Go :3001
```

Nginx should:

- terminate TLS;
- proxy both the Vue website and Go API requests to `127.0.0.1:3001`;
- preserve `Host`, client IP, and forwarded protocol headers;
- disable buffering for AI streaming endpoints;
- use a longer read timeout for AI requests;
- expose `/health` for deployment checks.

Start from `deploy/nginx/datamind.conf` and replace the domain, upstream
address, and certificate paths. Keep the Go service private to loopback or the
container network. Do not point this Go template at the hosted Cloud Node
port; the Cloud Node uses its own Nginx site configuration on `ny`.
