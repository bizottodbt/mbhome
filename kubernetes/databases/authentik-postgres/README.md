# Authentik PostgreSQL

Authentik uses a dedicated two-instance CloudNativePG cluster backed by the
`nfs-cache` storage class. The database and Authentik application credentials
are synchronized from Vault path `mbhome/apps/authentik/config`.

The Vault entry must contain these keys:

```text
username=authentik
password=<random database password>
AUTHENTIK_SECRET_KEY=<random 50+ character application secret>
```

Create the namespace-scoped Vault policy and role before reconciling the
database layer:

```bash
make vault-app-namespace-bootstrap VAULT_APP_NAMESPACE=authentik
```

Then write the secret with the Vault CLI. Do not change
`AUTHENTIK_SECRET_KEY` after the first installation.
