# Installation

This document explains how to install the precompiled DataMind Go/Vue server.
The distribution serves the web administration page and server APIs from the
same service.

## Requirements

- Linux AMD64 or ARM64 for a native systemd installation, or Windows with
  Docker Desktop Linux containers;
- permission to install a system service or run Docker;
- no pre-issued DataMind Cloud API key is required for interactive installation;
  the installer can register a free account, while non-interactive installation
  must provide an existing key through the environment;
- a reachable port, with `3001` used by default.

## Linux server

Run the bootstrap command as root. It first checks permissions, architecture,
required dependencies, external network access, a usable download source, and
port `3001`. It then downloads and verifies the matching Release and creates
`datamind-go.service`. Normal output reports pass/fail stages without exposing
the Cloud internal address or upstream HTTP status. When no existing DataMind
Cloud API key is available, the installer guides the user through registration:

```bash
{ curl -fsSL --connect-timeout 8 https://raw.githubusercontent.com/hujiangyi/data-mind-server/main/install/install-go.sh ||
  curl -fsSL --connect-timeout 8 https://gitee.com/hujiangyi/data-mind-server/raw/main/install/install-go.sh; } |
  sudo DATAMIND_GO_VERSION=v0.1.2 bash
```

The service listens on `0.0.0.0:3001` by default and serves both the Vue website
and server APIs. The installer checks port occupancy before installation and
waits for the process, listener, and health endpoint after startup.

To choose a release mirror explicitly:

```bash
export DATAMIND_RELEASE_SOURCE=gitee
```

Use `github`, `gitee`, or `auto`. The default `auto` mode checks reachability
and selects an available Release source.

The installer first uses the system network path and automatically tries one
direct connection if that path fails. If the server has a broken proxy
configuration, direct mode can also be selected explicitly:

```bash
sudo DATAMIND_CURL_NO_PROXY=1 DATAMIND_GO_VERSION=v0.1.2 bash ./install/install-go.sh
```

If the server must use a specific proxy, set:

```bash
sudo DATAMIND_CURL_PROXY=http://proxy.example.com:8080 \
  DATAMIND_GO_VERSION=v0.1.2 bash ./install/install-go.sh
```

When the network check fails, the installer exits before downloading the
binary instead of waiting through the rest of the installation.

## Windows with Docker Desktop

Windows does not use a native Go executable. Install and start Docker Desktop
with Linux Containers enabled, then run this command in PowerShell:

```powershell
irm https://raw.githubusercontent.com/hujiangyi/data-mind-server/main/install/install-go.ps1 | iex
```

The installer checks Docker Desktop, network access, and port availability,
selects the matching Linux Docker bundle, and starts the service. When no
existing Cloud API key is available, it guides the user through registration:

```text
http://127.0.0.1:3001
```

To install an explicit version:

```powershell
& .\install-go.ps1 -Version v0.1.2
```

The Windows installation does not require Go, MinGW, or a native Windows Go
build.

## Web account and first sign-in

After a fresh installation, open the Web management entrypoint shown by the
installer. The built-in administrator account is:

```text
username: admin
initial password: 123456
```

The first sign-in is intentionally incomplete. DataMind redirects the account
to a password-change page and requires a formal password with 8 to 16
characters before allowing access to business pages.

Administrator-created accounts and accounts reset by an administrator also
receive the fixed initial password `123456` and must change it at first sign-in.
Self-registered accounts choose an initial password during registration, but
they follow the same first-sign-in password-change step. Until the step is
complete, protected business routes are denied.

For an administrator to reset an account, use **User Management -> Edit User ->
Reset Initial Password**. The operation restores `123456` and marks the account
as requiring a first-sign-in change.

For server-side recovery or scripted administration:

```bash
sudo /opt/datamind-go/bin/daas-go \
  -config /opt/datamind-go/configs/config.yaml \
  -reset-password \
  -username admin
```

To set a final password directly from the server console:

```bash
sudo /opt/datamind-go/bin/daas-go \
  -config /opt/datamind-go/configs/config.yaml \
  -change-password \
  -username admin
```

The new console password must be 8 to 16 characters. These commands update
the SQLite account store and do not require a service restart. The Web account
password is separate from `DATAMIND_CLOUD_API_KEY`.

## Cloud registration and configuration

The Go service needs these server-side values to use the Cloud AI relay:

```text
DATAMIND_CLOUD_API_BASE
DATAMIND_CLOUD_API_KEY
```

### Recommended: automatic registration

On the first interactive run, when no key is detected, choose:

```text
1) 自动注册免费账号并生成 Key（推荐）
```

Provide a real mailbox that can receive mail and a Cloud login password with
at least 8 characters. The password is entered once with visible terminal
input. The installer calls the Cloud registration endpoint, receives a
`dm_free_...` key, and stores it in the restricted local configuration. A
newly obtained key is shown once with its server-side save location.

If the mailbox is already registered, the installer verifies the same Cloud
password and issues a fresh key; enter the password again if it does not match.
You can also register first at `https://dm.iter-self.top/` and paste the key
shown by the website into the installer. The registration password is only for
Cloud sign-in and cannot replace the API key. Other Cloud service credentials
are internal deployment details and are not DataMind Cloud API keys.

### Automated installation

Non-interactive installation requires an administrator to provide:

```text
DATAMIND_CLOUD_API_BASE
DATAMIND_CLOUD_API_KEY
```

The installer stores the key without echoing it. Do not put the key into
browser code, release archives, Docker images, or public issue reports.

## Public domain and Nginx

The service can run directly on port `3001`. After startup, the installer sends
a small welcome request through the configured Cloud AI capability and reports
success only after that check passes. For a public domain and HTTPS, configure
Nginx to proxy the domain to `127.0.0.1:3001`:

```text
https://data.example.com -> Nginx :443 -> DataMind Server :3001
```

See [Nginx deployment](nginx.md) for the reverse-proxy template. To avoid
directly exposing port `3001`, set `DATAMIND_BIND_ADDRESS=127.0.0.1` before
installation and use Nginx as the public entry point.

## Data and upgrades

The installer keeps runtime configuration and local SQLite data outside the
versioned binary files. Re-running the installer with a newer Release updates
the service while preserving the local data directory.

Stop and remove a Linux installation:

```bash
{ curl -fsSL https://raw.githubusercontent.com/hujiangyi/data-mind-server/main/install/uninstall-go.sh ||
  curl -fsSL https://gitee.com/hujiangyi/data-mind-server/raw/main/install/uninstall-go.sh; } |
  sudo bash
```

For Windows, use the matching `uninstall-go.ps1` script. Without the purge
option it removes the container while preserving local data.

## Related documentation

- [Cloud API keys](api-key.md)
- [Nginx deployment](nginx.md)
- [Release mirrors](release-mirrors.md)
- [Troubleshooting](troubleshooting.md)
- [Administrator guide](admin-guide.md)
