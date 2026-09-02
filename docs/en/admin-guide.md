# DataMind Administrator Guide

This guide is for the administrator taking over a DataMind deployment for the first time. It explains how to connect scattered business systems and assign access by employee, role, and business scope.

DataMind keeps database credentials on the server and exposes only server-validated capabilities to AI and ordinary users. Administrators can manage data sources, users, permission groups, tables, and data APIs from one place without giving an AI system a production database administrator account.

## 1. Sign in as an administrator

Open the DataMind Server website and go to the sign-in page.

- Use the administrator account supplied for the deployment;
- For a new private deployment, confirm the initial administrator account from the delivery materials;
- Never place an administrator password in scripts, issues, release notes, or chat messages;
- After the first sign-in, review the administrator email and password policy in System Settings.

The Cloud account and local DataMind Server employee account are separate identities:

- The Cloud account is used by the server to access Cloud AI and manage Cloud API keys;
- The Server employee account is used to sign in to the administration page and receive business permissions;
- Do not use a Cloud API key as an employee password or put an employee password in an AI tool.

## 2. Add a data source

Before adding a data source, verify that the DataMind Server host can reach the target database. A database administration page working in a browser does not prove that the server can reach the database.

Path: **Data Source Management -> Add Data Source**.

1. Choose a relational database or Hadoop;
2. Choose a database type such as MySQL, PostgreSQL, Oracle, or SQL Server;
3. Enter a name that identifies the system and purpose, such as `sales-prod` or `finance-readonly`;
4. Enter the host, port, database name, username, and password;
5. Select **Test Connection**;
6. After the connection succeeds, select the databases to manage;
7. Save the data source;
8. Run synchronization from the data source list to load database, table, and column metadata.

Use a read-only database account where possible. If controlled queries or data APIs require additional operations, grant only the database privileges required by that use case. Do not default to a database administrator account.

Data source passwords are server-side secrets:

- Enter them only in the trusted administration page;
- Do not place them in frontend code, public repositories, Docker images, or screenshots;
- Update and retest the data source after a database password changes;
- When the database uses an allowlist or TLS, configure the server egress address and certificate requirements as well.

## 3. Synchronize and review metadata

After saving a data source, confirm:

- the connection state is healthy;
- the database count is expected;
- tables and columns have been synchronized;
- the last synchronization time has changed;
- the table count has not unexpectedly decreased.

Use **Data Catalog** to browse databases, tables, and columns. Use **SQL Query** with a test employee account to validate that the expected metadata and data are visible.

When synchronization fails, check:

1. Database account validity;
2. Network access from the Server host;
3. Firewall, allowlist, port, and TLS configuration;
4. The selected data source type;
5. Metadata permissions for the database account;
6. Sanitized service logs and synchronization timestamps.

Do not expand database privileges just to bypass a synchronization error. Fix the connection, metadata permission, or data source configuration first.

## 4. Create employee accounts

Path: **User Management -> Add User**.

Enter:

- username;
- an 8 to 16 character login password;
- real name;
- employee number;
- a reachable email address;
- role and notes.

Roles such as Administrator, Data Administrator, API Operator, Data Quality Manager, Ordinary User, and Business User describe responsibilities. The actual data boundary should still be defined through permission groups and resource grants; do not treat a role label as the complete security policy.

When an employee leaves, changes roles, or has a compromised account:

- edit or delete the account;
- remove the account from permission groups;
- review its historical access records;
- revoke related data APIs when necessary;
- do not only rename the account while leaving its grants in place.

## 5. Create permission subjects and grants

Path: **Permission Management -> Add Permission Subject**.

A permission subject is a reusable set of grants, for example:

- East China Sales;
- Finance Read Only;
- Warehouse Operations;
- Project Managers.

Give each subject a clear name and description. Avoid descriptions such as “default” or “all access”.

Open the subject details and configure:

### User grants

Use **User Authorization** to select registered employee accounts. Prefer permission groups based on role, department, and business line instead of maintaining large lists of individual grants.

### Data grants

Use **Data Permissions** to choose data sources, databases, and tables. Apply least privilege:

- grant only required data sources;
- then grant only required databases;
- finally grant only required tables;
- choose read or write access deliberately;
- never grant an entire database merely because AI needs to understand a field.

For tables containing owner, department, region, tenant, or project fields, confirm the data-scope model and identity mapping before granting access. AI-assisted metadata analysis can suggest candidate owner fields, but an administrator must review the result before treating it as an effective policy.

### API grants

If the team publishes data APIs, use **API Permissions** to grant only the interfaces required by the employee. API SQL templates, parameters, and result ranges must remain consistent with the underlying table permissions.

## 6. Configure data scope and identity mapping

Table authorization says which table a user may access. It does not automatically say which rows inside that table belong to the user. Sales, customer, order, and project data usually need an additional data-scope and identity-mapping policy.

Recommended workflow:

1. Synchronize the target table metadata and limited statistics;
2. Confirm that it has an owner, employee number, user ID, name, or login field;
3. Add the table to the relevant permission group;
4. Review data-scope analyses and pending review tasks;
5. Resolve low-confidence or ambiguous candidates in Approval Center;
6. Bind the employee's external identity from the business system;
7. Run a protected query with that employee account;
8. Run the same scenario with an unauthorized employee and verify denial or filtering.

Identity bindings must be unique and traceable. An employee's username in DataMind is not necessarily the same as the name or employee ID stored in every business system.

## 7. Approvals and daily permission changes

Path: **Approval Center**.

Review:

- pending table permission requests;
- pending API permission requests;
- rejection reasons;
- withdrawn or deleted historical requests.

Before approval, confirm the applicant, job responsibility, business purpose, target table, and permission type. When rejecting a request, enter a clear reason so the employee can correct the scope.

After changing permissions, verify the behavior with a target employee account:

- authorized data sources are visible;
- unauthorized data sources are hidden;
- authorized tables can be queried;
- out-of-scope rows are filtered;
- unauthorized APIs are rejected.

## 8. Operational checklist

### Daily

- check the website and `/health`;
- review data-source status and synchronization time;
- inspect failed or unusual access in Audit Log;
- process pending requests in Approval Center;
- review data-quality and synchronization failures.

### Weekly

- review administrator, data administrator, and API operator membership;
- review permission-group members against current job responsibilities;
- remove unused data sources, table grants, and data APIs;
- sample access records for sensitive data;
- check backups, disk space, and log retention.

### When business or personnel changes

- transfer: remove the old grants before adding the new group;
- offboarding: disable the account and review recent access;
- database migration: test the new data source before switching grants;
- schema change: synchronize metadata and review data-scope analysis;
- API change: retest parameters, result fields, and permission boundaries.

## 9. Security boundary

DataMind enforces its security boundary on the server. It must not depend on browser buttons or an AI model voluntarily following the policy.

- ordinary employees receive only server-authorized data;
- administrator capabilities and ordinary-user capabilities are separated;
- changing client parameters cannot bypass server-side checks;
- database credentials, Cloud API keys, and employee passwords are stored separately;
- use HTTPS and Nginx in production and restrict the administration entry point where possible;
- public support reports should contain only masked logs, timestamps, and error categories.

Related deployment documentation:

- [Installation](installation.md)
- [Nginx deployment](nginx.md)
- [Troubleshooting](troubleshooting.md)
