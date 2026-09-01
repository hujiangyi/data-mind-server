# DataMind Server

DataMind Server is the public distribution and deployment repository for the
DataMind Go/Vue service.

This repository contains:

- Linux AMD64 and ARM64 installers;
- a Windows Docker installer;
- Docker Compose and runtime templates;
- Nginx deployment examples;
- server Releases, checksums, and compatibility notes;
- English and Simplified Chinese deployment documentation.

This repository does **not** contain the closed-source DataMind Go, Vue, or
Cloud source code. Server binaries are built in a private source repository
and manually uploaded to Releases here. The EULA attached to each Release
defines the permitted use of the binaries.

## Choose an installation method

### Linux server

Install a compiled Go server distribution:

```bash
{ curl -fsSL --connect-timeout 8 https://raw.githubusercontent.com/hujiangyi/data-mind-server/main/install/install-go.sh ||
  curl -fsSL --connect-timeout 8 https://gitee.com/hujiangyi/data-mind-server/raw/main/install/install-go.sh; } |
  sudo DATAMIND_GO_VERSION=v0.1.2 bash
```

The installer selects Linux AMD64 or ARM64, probes the Gitee and GitHub
Release mirrors, asks for the DataMind Cloud API key, and creates the
`datamind-go.service` systemd service.

### Windows

Windows does not use a native Go binary. Install and start Docker Desktop, then
run this command in PowerShell:

```powershell
irm https://raw.githubusercontent.com/hujiangyi/data-mind-server/main/install/install-go.ps1 | iex
```

The installer runs the precompiled Linux Go Docker distribution and exposes:

```text
http://127.0.0.1:3001
```

### Nginx and HTTPS

Production deployments should use an HTTPS domain and reverse proxy to the Go
service. See:

- [Nginx deployment](docs/en/nginx.md)
- [Windows Docker](docs/en/windows-docker.md)
- [Release mirrors](docs/en/release-mirrors.md)

## Server configuration

The server requires separate configuration for:

```text
DATAMIND_CLOUD_API_BASE
DATAMIND_CLOUD_API_KEY
DAAS_MCP_MASTER_KEY
DAAS_MCP_SETUP_BASE_URL
DAAS_MCP_PUBLIC_API_BASE
```

`DATAMIND_CLOUD_API_BASE` and `DATAMIND_CLOUD_API_KEY` connect the Go service
to DataMind Cloud. `DAAS_MCP_SETUP_BASE_URL` is the installation page included
in user emails. `DAAS_MCP_PUBLIC_API_BASE` is the Go service address used by
MCP clients. The Agnes API key is managed only inside the Cloud service and is
never part of server installation parameters.

For a remote deployment, set the public Go address before installation:

```bash
DAAS_MCP_PUBLIC_API_BASE=https://go.example.com \
DAAS_MCP_SETUP_BASE_URL=https://go.example.com \
sudo -E bash install/install-go.sh
```

## Release process

Server Release assets are built in a private source repository and uploaded
manually. This repository does not run cross-repository GitHub Actions and does
not store a publishing token.

Before publishing, verify:

```text
Release assets exist
checksums.txt is correct
Linux AMD64 installation succeeds
Linux ARM64 installation succeeds
Windows Docker installation succeeds
the Go health check succeeds
the Vue home page is reachable
MCP connects to the Go service
```

## License

The installers, deployment templates, and public documentation in this
repository are licensed under Apache License 2.0. Server binaries are not
published as open-source source code; the EULA attached to each Release
defines their use.

简体中文说明：[README.zh-CN.md](README.zh-CN.md)
