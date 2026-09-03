# Windows Docker Installation

The Go service is not distributed as a native Windows executable. Windows
users run the Linux build inside Docker Desktop Linux containers.

## Requirements

- Docker Desktop is installed and running.
- Docker Desktop is using Linux Containers.
- Docker Compose is available as `docker compose`.
- The host is Windows AMD64 or Windows ARM64.
- Interactive installation can register a free Cloud account, so a pre-issued
  DataMind Cloud API key is not required. Automated installation must provide
  an existing key through the environment.

Run the installer from PowerShell:

```powershell
irm https://raw.githubusercontent.com/hujiangyi/data-mind-server/main/install/install-go.ps1 | iex
```

The installer selects the matching Linux bundle:

```text
Windows AMD64 -> Linux AMD64
Windows ARM64 -> Linux ARM64
```

It downloads a versioned Docker bundle containing the compiled Linux Go
binary, runtime Dockerfile, Compose file, configuration template, and
migrations. The installer checks Docker, external network access, and port
availability before downloading. If no DataMind Cloud API key is available, it
guides the user through mailbox/password registration and obtains a free key.
For an existing mailbox, it verifies the password and issues a fresh key. The
password is entered once with visible terminal input. After starting the
container, the installer waits for the container health state, local port, and
Cloud AI welcome check to pass. The menu also supports entering an existing key.

The default endpoint is:

```text
http://127.0.0.1:3001
```

To install a specific release:

```powershell
& .\install-go.ps1 -Version v0.1.4
```

The installer probes Gitee first and GitHub second. Override the behavior when
needed:

```powershell
& .\install-go.ps1 -Version v0.1.4 -ReleaseSource gitee
```

The environment variables `DATAMIND_RELEASE_SOURCE` and
`DATAMIND_RELEASE_BASE` can also select a source or a private mirror.

The installer does not require Go, MinGW, or a Windows Go binary.

## Data and upgrades

Runtime data is stored under:

```text
%LOCALAPPDATA%\DataMind\data
```

Configuration and the DataMind API Key are stored under the same installation
directory. A newly obtained key is shown once with its save location. Upgrades
replace the versioned binary and runtime files while preserving the local
configuration and SQLite data.

Stop and remove the container while keeping data:

```powershell
& .\uninstall-go.ps1
```

Remove the container and local data:

```powershell
& .\uninstall-go.ps1 -PurgeData
```

The Docker container uses the same Go-to-Cloud AI API contract as the native
Linux installation.
