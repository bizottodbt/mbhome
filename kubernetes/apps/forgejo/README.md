# Forgejo

Forgejo is deployed by Flux as an internal Git service for private homelab
repositories and experiments.

```text
https://git.apps.mbhome.biz
```

The platform `mbhome` repository should stay mirrored outside the cluster. Do
not make this in-cluster Forgejo instance the only recovery source for the
cluster itself.

## Architecture

- Forgejo Helm chart from `oci://code.forgejo.org/forgejo-helm/forgejo`
- single Forgejo pod; the upstream chart warns not to scale replicas above `1`
  for normal deployments
- repository/application data on `nfs-user`
- PostgreSQL provided by CloudNativePG in the same `forgejo` namespace
  owned by the database layer, also using `nfs-user`
- HTTPS exposure through the internal Cilium Gateway
- SSH clone access disabled for the first deployment; use HTTPS clone URLs
- Dex OIDC login with local password registration disabled

## Bootstrap

Create the database owner secret before reconciling the database layer:

```bash
export FORGEJO_POSTGRES_PASSWORD="$(openssl rand -hex 32)"
make forgejo-postgres-secret
```

This stores the value in Vault at `mbhome/apps/forgejo/postgres`. Vault Secrets
Operator creates and keeps `forgejo/forgejo-postgres-app` synced from that path.

Bootstrap the namespace Vault role once before Flux reconciles the Forgejo
database and app layers:

```bash
make vault-app-namespace-bootstrap VAULT_APP_NAMESPACE=forgejo
```

Create the Forgejo internal app secrets:

```bash
make forgejo-config-secret
```

This generates values unless you pre-export them:

```text
FORGEJO_SECURITY_SECRET_KEY
FORGEJO_SECURITY_INTERNAL_TOKEN
FORGEJO_OAUTH2_JWT_SECRET
FORGEJO_SERVER_LFS_JWT_SECRET
```

Those values are stored in Vault at `mbhome/apps/forgejo/config`. Vault Secrets
Operator creates and keeps `forgejo/forgejo-config` synced from that path.

Create the initial admin secret in Vault:

```bash
export FORGEJO_ADMIN_USERNAME=forgejo_admin
export FORGEJO_ADMIN_PASSWORD="$(openssl rand -base64 36)"
make forgejo-admin-secret
```

Create the shared Dex/Forgejo OAuth client secret:

```bash
export FORGEJO_OAUTH_CLIENT_SECRET="$(openssl rand -hex 32)"
make forgejo-oauth-secret
```

That target writes one generated value into:

```text
mbhome/apps/dex/forgejo                 -> dex/dex-forgejo-client
mbhome/apps/forgejo/oauth               -> forgejo/forgejo-oauth
```

The Make targets do not create those Kubernetes Secrets directly. Vault is the
source of truth; Vault Secrets Operator creates the namespace-local Secrets.

The Forgejo OAuth secret uses the upstream chart format:

```text
key    = forgejo
secret = <generated-client-secret>
```

Then commit, push, and reconcile:

```bash
make flux-reconcile
make forgejo-status
```

The chart is configured with `passwordMode: initialOnlyRequireReset`, so the
initial admin password is only used at first creation and Forgejo should require
changing it on first login.

Dex is configured as the OIDC provider with this redirect URI:

```text
https://git.apps.mbhome.biz/user/oauth2/dex/callback
```

Forgejo allows external registration only. That means a first-time Dex user can
be created by logging in with Dex, but the local password registration button is
not shown.

## Notes

Forgejo is useful as an internal/private Git service, but avoid circular
recovery dependencies:

- keep the main cluster GitOps repo in GitHub or mirrored externally
- back up Forgejo data and PostgreSQL before relying on it for important repos
- use deploy keys for Flux access to private Forgejo repos later
