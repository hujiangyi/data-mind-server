# Installation

The installer configures the MCP client for an existing DataMind Go service.
It does not create or replace MCP credentials.

For a Go service with email delivery enabled, register in the Go web interface
with a real mailbox first. The service sends the MCP installation parameters to
that mailbox and keeps them out of the HTTP registration response. For an
existing private deployment, an administrator may issue the credential pair
instead.

Required values:

- `--tool`
- `--api-base`
- `--credential`
- `--master-key`

Supported tools:

`claude-desktop`, `claude-code`, `cursor`, `vscode`, `opencode`, and
`continue`.

The installer downloads a versioned MCP release asset, writes the existing
MCP environment variables, and marks the credential as used on the Go
service. It never writes a cloud API key.

After installation, configure the Go service separately:

```bash
datamind cloud auth add --name free --key "$DATAMIND_FREE_KEY"
datamind cloud auth use --name free
```

## Windows Go service

Windows does not use a native Go executable. Use Docker Desktop Linux
containers and the dedicated installer:

```powershell
irm https://raw.githubusercontent.com/hujiangyi/data-mind-server/main/install/install-go.ps1 | iex
```

The installer downloads the matching Linux Docker bundle, asks for the
DataMind Cloud API Key, and starts the service at `http://127.0.0.1:3001`.
See [Windows Docker](windows-docker.md) for upgrades and data management.

## Linux Go service

Install the compiled Linux Go service as a systemd service:

```bash
{ curl -fsSL --connect-timeout 8 https://raw.githubusercontent.com/hujiangyi/data-mind-server/main/install/install-go.sh ||
  curl -fsSL --connect-timeout 8 https://gitee.com/hujiangyi/data-mind-server/raw/main/install/install-go.sh; } |
  sudo DATAMIND_GO_VERSION=v0.1.2 bash
```

The script supports Linux AMD64 and ARM64, automatically probes the Gitee and
GitHub Release mirrors, verifies the Release checksum, asks for the DataMind
Cloud API Key, and starts `datamind-go.service` on `127.0.0.1:3001`. It does
not change Nginx configuration.

For a remote deployment, set the public Go address before running the installer:

```bash
export DAAS_MCP_PUBLIC_API_BASE=https://go.example.com
export DAAS_MCP_SETUP_BASE_URL=https://go.example.com
```

See [Release mirrors](release-mirrors.md) for source selection variables.
