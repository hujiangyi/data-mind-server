# Installation

This document explains how to install the precompiled DataMind Go/Vue server.
The distribution serves the web administration page and server APIs from the
same service.

## Requirements

- Linux AMD64 or ARM64 for a native systemd installation, or Windows with
  Docker Desktop Linux containers;
- permission to install a system service or run Docker;
- a DataMind Cloud API key for the server-to-Cloud AI connection;
- a reachable port, with `3001` used by default.

## Linux server

Run the bootstrap command as root. It selects the matching architecture,
probes the Gitee and GitHub Release mirrors, verifies the downloaded checksum,
asks for the DataMind Cloud API key, and creates `datamind-go.service`:

```bash
{ curl -fsSL --connect-timeout 8 https://raw.githubusercontent.com/hujiangyi/data-mind-server/main/install/install-go.sh ||
  curl -fsSL --connect-timeout 8 https://gitee.com/hujiangyi/data-mind-server/raw/main/install/install-go.sh; } |
  sudo DATAMIND_GO_VERSION=v0.1.2 bash
```

The service listens on `127.0.0.1:3001` by default and serves both the Vue
website and server APIs.

To choose a release mirror explicitly:

```bash
export DATAMIND_RELEASE_SOURCE=gitee
```

Use `github`, `gitee`, or `auto`. The default `auto` mode checks reachability
and selects an available Release source.

## Windows with Docker Desktop

Windows does not use a native Go executable. Install and start Docker Desktop
with Linux Containers enabled, then run this command in PowerShell:

```powershell
irm https://raw.githubusercontent.com/hujiangyi/data-mind-server/main/install/install-go.ps1 | iex
```

The installer selects the matching Linux Docker bundle, asks for the Cloud API
key, and starts the service at:

```text
http://127.0.0.1:3001
```

To install an explicit version:

```powershell
& .\install-go.ps1 -Version v0.1.2
```

The Windows installation does not require Go, MinGW, or a native Windows Go
build.

## Cloud configuration

The Go service needs these server-side values to use the Cloud AI relay:

```text
DATAMIND_CLOUD_API_BASE
DATAMIND_CLOUD_API_KEY
```

The installer asks for the key without echoing it and stores the local
configuration with restricted permissions. Do not put the key into browser
code, release archives, Docker images, or public issue reports.

## Public domain and Nginx

The service can run directly on port `3001`. For a public domain and HTTPS,
configure Nginx to proxy the domain to `127.0.0.1:3001`:

```text
https://data.example.com -> Nginx :443 -> DataMind Server :3001
```

See [Nginx deployment](nginx.md) for the reverse-proxy template. Keep the Go
service bound to loopback or the private container network when Nginx is used.

## Data and upgrades

The installer keeps runtime configuration and local SQLite data outside the
versioned binary files. Re-running the installer with a newer Release updates
the service while preserving the local data directory.

Stop and remove a Linux installation:

```bash
sudo systemctl disable --now datamind-go.service
sudo rm -f /etc/systemd/system/datamind-go.service
sudo systemctl daemon-reload
```

For Windows, use the matching `uninstall-go.ps1` script. Without the purge
option it removes the container while preserving local data.

## Related documentation

- [Cloud API keys](api-key.md)
- [Nginx deployment](nginx.md)
- [Release mirrors](release-mirrors.md)
- [Troubleshooting](troubleshooting.md)
