# DataMind Privacy Policy

Last updated: September 4, 2026

## 1. Privacy commitment

DataMind does not retain or record users' private business data. You can use
DataMind with confidence.

“Private business data” means business table contents, query results, files
sent to business data sources, and internal business information accessed
through DataMind. DataMind Cloud does not write this content to a long-term
business database or record it for profiling, advertising, or other commercial
purposes.

## 2. Local deployment boundary

DataMind Go runs on a Linux server, Docker environment, or other deployment
environment controlled by the user or organization. To provide management and
authorization features, the deployment may store locally:

- data-source connection configuration and necessary credentials;
- data-source, database, table, and field metadata;
- local users, subaccounts, roles, permission groups, and data permissions;
- operational audit information needed for troubleshooting and security
  governance;
- runtime configuration, migration records, and the necessary Cloud API key.

This is the user's own deployment data and is not automatically uploaded to
DataMind Cloud. Users are responsible for protecting the server, backups,
logs, database credentials, and Cloud API keys under their security controls.

## 3. Cloud AI requests

When Cloud AI is enabled, DataMind Go sends the minimum request needed to
complete the user's operation to DataMind Cloud and the configured upstream AI
service. DataMind Cloud provides relay, authentication, quota, and runtime
services; it does not retain private business data as a business purpose.

DataMind may retain non-content operational information such as account,
key, usage, request status, and error type for authentication, billing,
rate limiting, security, and troubleshooting. Request bodies, query results,
and business field values should not be written to these operational records.

## 4. Accounts and keys

Email addresses, Cloud accounts, and DataMind API keys are used for identity,
authorization, and usage management. Users must protect passwords, API keys,
database passwords, and server access, and must not commit them to public
repositories, issues, chat records, or public logs.

## 5. Third-party services

If users configure third-party databases, mail, AI, or payment services, those
services process data under the agreement between the user and the provider.
Users should independently review each provider's privacy, security, and data
retention policies.

## 6. Reinstallation and deletion

An update preserves local data and configuration. Reinstallation deletes local
DataMind data and configuration, including connected data sources, assigned
subaccounts, data permissions, and local audit data. Reconfiguration is
required after reinstall. Server backups, Docker volumes, operating-system
logs, and copies held by third-party services are not automatically deleted by
the installer and must be handled under the user's retention policy.

## 7. Contact and changes

This policy may be updated when the product's privacy boundary or data
handling changes. Material changes will be identified in public documentation
or the corresponding Release notes. Using DataMind means that the user
understands and accepts the boundaries for local deployment, Cloud AI requests,
and third-party services described here.
