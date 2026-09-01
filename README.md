# DataMind Server

DataMind Server is the public distribution and deployment repository for the
DataMind Go/Vue data platform. It is designed for small and medium-sized teams
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
  sudo DATAMIND_GO_VERSION=v0.1.2 bash
```

The installer selects Linux AMD64 or ARM64, probes the Gitee and GitHub
Release mirrors, asks for the DataMind Cloud API key, and creates the
`datamind-go.service` systemd service. The service listens on
`127.0.0.1:3001` by default and serves both the Vue website and server APIs.

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

### Nginx and HTTPS

Production deployments should use an HTTPS domain and reverse proxy to the Go
service. See:

- [Nginx deployment](docs/en/nginx.md)
- [Windows Docker](docs/en/windows-docker.md)
- [Release mirrors](docs/en/release-mirrors.md)

## Register for Cloud and install the server

### 1. Register a DataMind Cloud account

Open the hosted DataMind Cloud website:

```text
https://dm.iter-self.top/
```

In the registration form, provide:

- a real mailbox that can currently receive mail;
- a login password with at least 8 characters.

After a successful registration, the page returns:

- the account email and account ID;
- a free Cloud API key in the form `dm_free_...`;
- `keyKind: free`;
- the current free plan and usage information.

The free key is used by the Go service to access the Cloud AI relay. Copy it
after registration and store it securely. The mailbox address must be correct
because it may be needed for future login, account management, or service
notifications.

The registration email and password are only for signing in to Cloud; they
cannot replace the Cloud API key. An upstream Agnes API key is an internal
Cloud provider credential and must not be used to install DataMind Server.

### 2. Use the free key to install the server

On a Linux server, run:

```bash
{ curl -fsSL --connect-timeout 8 https://raw.githubusercontent.com/hujiangyi/data-mind-server/main/install/install-go.sh ||
  curl -fsSL --connect-timeout 8 https://gitee.com/hujiangyi/data-mind-server/raw/main/install/install-go.sh; } |
  sudo DATAMIND_GO_VERSION=v0.1.2 bash
```

When the installer displays:

```text
请输入 DataMind API Key：
```

Paste the `dm_free_...` key returned after registration. Input is hidden.
The installer stores the key in the server-side configuration with restricted
permissions; you do not need to edit `/opt/datamind-go` manually.

On Windows, install and start Docker Desktop, then run this command in
PowerShell:

```powershell
irm https://raw.githubusercontent.com/hujiangyi/data-mind-server/main/install/install-go.ps1 | iex
```

The Windows installer securely asks for the same DataMind Cloud API key. After
installation, the default local endpoint is:

```text
http://127.0.0.1:3001
```

### 3. Use environment variables for non-interactive installation

Automated deployments can provide:

```bash
export DATAMIND_CLOUD_API_BASE=https://dm.iter-self.top/v1
export DATAMIND_CLOUD_API_KEY='dm_free_...'
```

Then run the local installer:

```bash
sudo -E DATAMIND_GO_VERSION=v0.1.2 bash ./install/install-go.sh
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
- `checksums.txt`;
- a Release manifest and licensing documents.

## License

The installers, deployment templates, and public documentation in this
repository are licensed under Apache License 2.0. Server binaries are not
published as open-source source code; the EULA attached to each Release
defines their use.

简体中文说明：[README.zh-CN.md](README.zh-CN.md)
