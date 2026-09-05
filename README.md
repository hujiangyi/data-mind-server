# DataMind Server

DataMind Server is the public distribution and deployment repository for the
DataMind data platform. It is designed for small and medium-sized teams
and enterprises that need to connect scattered business data, manage access
by business scope, and use AI without handing unrestricted database privileges
to an AI system.

This repository contains compiled server distributions, the Vue web
application embedded in those distributions, Docker runtime bundles,
installation scripts, and Nginx deployment templates. It does **not** contain
the closed-source DataMind Go, Vue, or Cloud source code. Server binaries are
built in a private source repository and manually uploaded to Releases. The
EULA attached to each Release defines the permitted use of the binaries.

## The problem DataMind solves

Business data is often spread across CRM, orders, inventory, finance, support,
project management, and internal operations systems. The data may also live in
multiple MySQL, PostgreSQL, or other databases. Teams then face a familiar
set of problems:

- Data is fragmented across systems, so cross-system reporting depends on
  manual exports.
- The same customer, order, product, or project is difficult to relate across
  separate applications.
- Giving an AI a database account creates an unnecessarily broad permission
  boundary and can expose unrelated data or allow out-of-scope queries.
- Refusing AI access altogether prevents teams from using AI for retrieval,
  schema understanding, operational analysis, and routine data management.
- Administrators need to assign access by department, role, business line,
  data source, and business scope while keeping an auditable trail.

DataMind is a **controlled data platform and AI data-access boundary**. It does
not require a team to migrate every existing system into a new database on
day one. Instead, it provides a unified service for connecting existing data
sources, managing metadata, exposing query entrypoints, applying user
permissions, and retaining operational audit information.

## Typical use cases

### One data entrypoint for a growing team

When sales, operations, warehouse, and finance use different systems, the team
can connect those sources to DataMind and use one administration surface to
inspect connection status, databases, and table structures. Users can organize
and query data only within their assigned business scope.

For example, a sales lead can relate customers to orders, an operations user
can inspect orders and inventory, and a finance user can reconcile payments
against financial records without receiving access to every department's data.

### Multi-system data management for enterprises

For organizations with multiple applications, departments, or tenants,
DataMind acts as a consistent data-access layer. Existing business systems can
keep their current storage and operational model while DataMind provides a
central place to manage data sources, metadata, and authorization boundaries.

Common relationships include:

- customers, contacts, and sales opportunities;
- orders, products, inventory, and logistics;
- payments, invoices, contracts, and customer entities;
- support tickets, service records, and product issues;
- projects, members, cost, and delivery progress.

### AI-assisted data management

Teams can use AI to understand schemas, locate business data, draft query
intent, summarize results, and identify anomalies while keeping actual data
access under server-side control. The AI does not need a production database
account or a database administrator privilege.

Each request is checked by the DataMind service against the current identity,
role, data-source permissions, and business scope before a controlled
connection executes it. This gives teams a practical balance between wanting
AI to manage data and refusing to give AI unrestricted access to the whole
database.

## How it works

1. **Connect existing sources.** Administrators configure business databases
   without requiring a change to the source systems' storage model.
2. **Provide a unified data view.** The web application exposes data sources,
   databases, tables, and metadata through one service.
3. **Assign permissions by scope.** Access can be separated by user,
   organization, role, business line, data source, database, table, and
   business scope.
4. **Execute through the server.** The Go service opens the data connection and
   performs authorization checks instead of handing production credentials to
   an AI system or an ordinary user.
5. **Constrain returned data.** The service applies the current user's
   authorized scope so that changing client parameters cannot grant access to
   unrelated data.
6. **Retain operational evidence.** Key access results, states, and runtime
   information remain available for troubleshooting, review, and governance.

## Security boundaries

DataMind is intended for deployments that need:

- ordinary users to see only assigned data sources and business scopes;
- administrators to manage users, roles, data sources, and authorization
  relationships centrally;
- AI to use controlled server capabilities instead of a database superuser
  account;
- Cloud API keys to remain on the Go service for access to the Cloud AI relay;
- deployment on an organization's own Linux server or Docker environment.

## What the public distribution includes

- Linux AMD64 and ARM64 installers;
- macOS AMD64 and ARM64 Go server and CLI binaries;
- Linux AMD64 and ARM64 Go server and CLI binaries;
- Linux Docker bundles for Windows Docker Desktop;
- Docker Compose and runtime templates;
- Nginx reverse-proxy deployment examples;
- Release checksums and compatibility notes;
- English and Simplified Chinese installation, deployment, and troubleshooting
  documentation.

## Choose an installation method

### Linux server

Install a compiled Go/Vue server distribution:

```bash
{ curl -fsSL --connect-timeout 8 https://raw.githubusercontent.com/hujiangyi/data-mind-server/main/install/install-go.sh ||
  curl -fsSL --connect-timeout 8 https://gitee.com/hujiangyi/data-mind-server/raw/main/install/install-go.sh; } |
  sudo DATAMIND_GO_VERSION=v0.1.10 bash
```

The installer first checks system dependencies, external network access, a usable
download source, and port `3001`, then selects Linux AMD64 or ARM64. Normal
output reports pass/fail stages without exposing the Cloud internal address or
upstream HTTP details.
If no DataMind Cloud API key is already available, it guides the user through
an email/password registration, obtains a free key, and then creates the
`datamind-go.service` systemd service. If the mailbox already exists, a matching
Cloud password signs a fresh usable key without another registration. The
service listens on `0.0.0.0:3001` by default and serves both the Vue website and
server APIs. After installation, the script prints both the local loopback address
`http://127.0.0.1:3001` and a server access address in the form
`http://{server_ip}:3001`. The server IP is detected automatically when possible;
set `DATAMIND_SERVER_IP` to override it.

### Windows

Windows does not receive a native Go executable. Install and start Docker
Desktop, then run this command in PowerShell:

```powershell
irm https://raw.githubusercontent.com/hujiangyi/data-mind-server/main/install/install-go.ps1 | iex
```

The installer downloads the precompiled Linux Docker distribution and exposes
the service locally at:

```text
http://127.0.0.1:3001
```

The container port is bound to `0.0.0.0:3001` by default; local access still uses
`http://127.0.0.1:3001`.

### Web account and first sign-in

For a fresh installation, the built-in administrator account is:

```text
username: admin
initial password: 123456
```

The initial password is intentionally fixed and temporary. The first sign-in
must go through the password-change page and set a formal password of 8 to 16
characters before the administration pages can be used.

Administrator-created employee accounts and administrator password resets also
use the fixed initial password `123456`. The employee must change it at the
first sign-in. Self-registered users choose an initial password during
registration, but they must also replace it at their first sign-in. Until that
change is complete, protected server business routes remain blocked.

The web account password is separate from the DataMind Cloud API key used by
the Go service. Do not paste one in place of the other.

DataMind does not retain or record users' private business data. See the
[Privacy Policy](docs/en/privacy-policy.md) for the complete data-handling
boundary.

### Nginx and HTTPS

Production deployments should use an HTTPS domain and reverse proxy to the Go
service. See:

- [Nginx deployment](docs/en/nginx.md)
- [Administrator guide](docs/en/admin-guide.md)
- [Windows Docker](docs/en/windows-docker.md)
- [Release mirrors](docs/en/release-mirrors.md)

## Register for Cloud and install the server

### 1. Run the installer and register automatically (recommended)

On a Linux server, run:

```bash
{ curl -fsSL --connect-timeout 8 https://raw.githubusercontent.com/hujiangyi/data-mind-server/main/install/install-go.sh ||
  curl -fsSL --connect-timeout 8 https://gitee.com/hujiangyi/data-mind-server/raw/main/install/install-go.sh; } |
  sudo DATAMIND_GO_VERSION=v0.1.10 bash
```

On Windows, install and start Docker Desktop, then run:

```powershell
irm https://raw.githubusercontent.com/hujiangyi/data-mind-server/main/install/install-go.ps1 | iex
```

During a first interactive installation without an existing key, the installer
shows:

```text
1) 自动注册免费账号并生成 Key（推荐）
2) 输入已有 DataMind API Key
3) 退出安装
```

Choose `1` and provide:

- a real mailbox that can currently receive mail;
- a Cloud login password with at least 8 characters, entered once. The
  installer intentionally uses visible terminal input for this password.

The installer calls the Cloud registration endpoint, obtains a free
`dm_free_...` DataMind Cloud API key, and stores it in the restricted
server-side configuration. If the mailbox already exists, the same email and
password are verified and a fresh key is issued. A newly obtained key is shown
once with its server-side save location; do not share the terminal output.
Before reporting success, the installer waits for the service process, port
listener, health endpoint, and Cloud AI welcome capability to pass. The default
local endpoint is:

```text
http://127.0.0.1:3001
```

The mailbox must be real and able to receive mail for future Cloud login and
account management. The registration password is only for Cloud sign-in; it
cannot replace the API key. Other Cloud service credentials are internal
deployment details and must not be used to install DataMind Server.

### 2. Existing account or web registration

If the mailbox is already registered, the installer verifies the Cloud password
and obtains a fresh DataMind Cloud API key. If the password does not match, enter
it again. As an alternative, open:

```text
https://dm.iter-self.top/
```

Complete the registration form with a real mailbox and a password of at least
8 characters. The page shows the account information, free plan information,
and the `dm_free_...` key after registration. Choose “输入已有 DataMind API
Key” in the installer and paste the key; input is hidden.

### 3. Use environment variables for non-interactive installation

Automated deployments can provide:

```bash
export DATAMIND_CLOUD_API_BASE=https://dm.iter-self.top/v1
export DATAMIND_CLOUD_API_KEY='dm_free_...'
```

Then run the local installer:

```bash
sudo -E DATAMIND_GO_VERSION=v0.1.10 bash ./install/install-go.sh
```

An API key in an environment variable may enter shell history or automation
logs. Prefer the interactive prompt for ordinary installations and clear the
environment variable after deployment.

### 4. Verify the plan and usage

After installation, use the Go CLI to inspect the profile, plan, and usage:

```bash
datamind cloud auth add --name free --key '<your-dm-free-key>'
datamind cloud auth use --name free
datamind cloud auth list
datamind cloud plan --base-url https://dm.iter-self.top
datamind cloud usage --base-url https://dm.iter-self.top
```

`auth list` prints masked keys only. When membership is enabled, the website
will issue a separate member key; save it as another profile and switch
profiles without changing the server program.

## Release process

Each Release includes:

- platform-specific server and CLI binaries;
- Windows Docker distributions;
- the `datamind-upgrade` binary and complete database migration chain inside
  every Go server archive;
- `migration-manifest.json`, `configs/config.yaml`, `VERSION`, and checksums;
- `checksums.txt`;
- a Release manifest and licensing documents.

The Go server archive is not a raw binary-only package. It must contain:

```text
bin/daas-go
bin/datamind-upgrade
migrations/
migration-manifest.json
configs/config.yaml
VERSION
```

The installer refuses a Release that is missing `bin/datamind-upgrade` or
`migration-manifest.json`. An old Release must not be used to work around this
check; publish the complete asset set as a new Release instead.

## License

The installers, deployment templates, and public documentation in this
repository are licensed under Apache License 2.0. Server binaries are not
published as open-source source code; the EULA attached to each Release
defines their use.

简体中文说明：[README.zh-CN.md](README.zh-CN.md)
