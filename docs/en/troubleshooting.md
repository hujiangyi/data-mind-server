# Troubleshooting

## The service does not start

Check the service status and recent logs:

```bash
sudo systemctl status datamind-go.service
sudo journalctl -u datamind-go.service -n 100 --no-pager
```

For a Docker installation, check the container and Compose logs:

```bash
docker ps -a
docker compose logs --tail=100
```

Confirm that the host has the expected architecture, that port `3001` is not
already occupied, and that the installation directory is readable by the
service account.

## The website or API cannot be reached

Start with the local health endpoint:

```bash
curl -i http://127.0.0.1:3001/health
```

If the local endpoint works but the domain does not, inspect the Nginx
upstream, DNS record, firewall, TLS certificate, and the configured domain
name. Nginx should proxy to `127.0.0.1:3001` and should not point to the
Cloud service's port.

## Cloud AI is unavailable

Run the local diagnostics and inspect the active Cloud profile:

```bash
datamind doctor
datamind cloud plan --base-url https://dm.iter-self.top
datamind cloud usage --base-url https://dm.iter-self.top
```

Confirm that the Cloud API base URL is reachable, the configured API key is
valid, the account has available quota, and the membership or queue status is
what the operator expects. Never paste the complete key into a log or issue.

## A user registration email was not received

First verify that the mailbox address was entered correctly, can currently
receive mail, and has been checked for spam, promotions, quarantine, and
enterprise mail-gateway filtering. Mail providers apply different filtering
rules, so retrying with another real and reachable mailbox is recommended.

If several valid mailboxes fail to receive the message, contact the service
operator with the registration time and a masked mailbox address. Do not paste
complete credentials, API keys, or customer data into a public issue.

## A data source or query fails

Check the data source address, port, database name, account status, network
allowlist, and TLS requirements. Confirm that the service host can reach the
database independently of the browser. Review the service log for the
sanitized error, datasource name, operation, and request time; do not include
passwords or full customer records.
