# Cloud API Keys

A DataMind Cloud API key is a server-side credential used by the Go service
to access the DataMind Cloud AI relay. It is separate from database
credentials and must never be embedded in browser code, a public repository,
or a user's local AI tool configuration.

The interactive installer can collect a mailbox and Cloud login password,
call the hosted Cloud registration endpoint, and obtain a free key, so a
new user does not have to open the registration page first. Manual
registration through the hosted website is also supported. A successful
membership activation issues a member key with the corresponding usage
entitlement. The free key remains available, while the Go CLI prefers the
member key when it is active.

Use a real mailbox that can receive mail and a password with at least
8 characters. The mailbox is used for future Cloud sign-in and account
management. The registration password cannot replace the API key, and an
upstream Agnes `cpk_...` key is an internal provider credential rather than
a DataMind Cloud API key.

## Configure profiles

Store the keys in the local DataMind CLI profile:

```bash
datamind cloud auth add --name free --key '<free-key>'
datamind cloud auth add --name member --key '<member-key>'
datamind cloud auth use --name member
datamind cloud auth list
datamind cloud plan --base-url https://dm.iter-self.top
datamind cloud usage --base-url https://dm.iter-self.top
```

Use the free profile when no membership is active:

```bash
datamind cloud auth use --name free
```

Only masked keys are printed by `auth list`. Keep the profile file readable
only by the service account or current user. Rotate a key immediately after
suspected exposure, and do not put the replacement key into release archives,
Docker images, browser storage, or issue reports.

For a private deployment, replace the hosted Cloud base URL with the
operator's Cloud URL. The Go service should be the only component that stores
and uses the Cloud API key.
