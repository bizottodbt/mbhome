# Dex

Dex bridges Microsoft AD DS LDAP to Kubernetes OIDC.

This deployment is internal-only:

```text
https://dex.apps.mbhome.biz
```

Dex uses a dedicated CloudNativePG PostgreSQL database as its storage backend.
That lets Dex run multiple replicas without splitting browser login state across
pods.

Create the database owner secret before Flux reconciles the database layer:

```bash
export DEX_POSTGRES_PASSWORD='...'
make dex-postgres-secret
```

Check the database and operator with:

```bash
make cloudnative-pg-status
make dex-postgres-status
```

The AD connector uses LDAPS on port `636`. It currently skips certificate
verification while the DCs use lab self-signed LDAPS certificates; replace that
with `rootCAData` after AD CS issues trusted DC certificates.

Token lifetimes are set explicitly:

```text
ID token: 1 hour
Refresh token idle lifetime: 7 days
Refresh token absolute lifetime: 30 days
```

Refresh sessions and signing keys are stored in Postgres, so restarting Dex pods
does not wipe OIDC state. If the database is rebuilt from scratch, existing
refresh sessions and signing keys are lost and users must log in again.

Create the LDAP bind secret before Flux reconciles the identity layer:

```bash
export DEX_LDAP_BIND_DN='CN=svc_dex,OU=Service Accounts,OU=home,DC=mbhome,DC=biz'
export DEX_LDAP_BIND_PASSWORD='...'
make dex-ldap-secret
```

The initial Kubernetes CLI client is public and uses local redirect URLs for
`kubelogin`/`oidc-login`:

```text
client id: kubernetes
issuer: https://dex.apps.mbhome.biz
```

Grafana uses Dex as a confidential OAuth client:

```text
client id: grafana
redirect URI: https://grafana.apps.mbhome.biz/login/generic_oauth
```

Create the shared Grafana client secret before reconciling Flux. The same
generated value is stored in `dex/dex-grafana-client` for Dex and
`monitoring/grafana-oauth` for Grafana:

```bash
export GRAFANA_OAUTH_CLIENT_SECRET='...'
make grafana-oauth-secret
```

Vault also uses Dex as a confidential OAuth client:

```text
client id: vault
UI redirect URI: https://vault.apps.mbhome.biz/ui/vault/auth/oidc/oidc/callback
CLI redirect URI: http://localhost:8250/oidc/callback
```

Create the shared Vault client secret before reconciling Flux. The generated
value is stored in `dex/dex-vault-client` for Dex and is entered into Vault by
the interactive bootstrap target:

```bash
export VAULT_OIDC_CLIENT_SECRET='...'
make vault-oidc-secret
```

The repo includes a credential-free OIDC kubeconfig template at
`kubernetes/clusters/mbhome/kubeconfig.oidc.yaml`. Install it into your home
directory for day-to-day access:

```bash
make kubernetes-oidc-context
export KUBECONFIG="${HOME}/.kube/mbhome-oidc"
kubectl auth whoami
```

`kubectl auth whoami` invokes `kubectl oidc-login` when no valid token is
cached. The committed OIDC kubeconfig uses `--skip-open-browser`, so the plugin
prints the localhost callback URL instead of opening browser tabs automatically.
That callback then redirects to Dex.

Or merge the OIDC context into the default kubeconfig and select it:

```bash
make kubernetes-oidc-merge-context
unset KUBECONFIG
kubectl auth whoami
```

If `KUBECONFIG` is still exported, plain `kubectl` keeps using that file
instead of the merged default `~/.kube/config`.

To test the merged mbhome OIDC context while ignoring any current shell
`KUBECONFIG` override:

```bash
make kubernetes-oidc-whoami
```

If the Kubernetes API endpoint or cluster CA changes, regenerate the committed
template from the Talos admin kubeconfig:

```bash
make dex-generate-oidc-kubeconfig
```

AD groups mapped for Kubernetes RBAC:

```text
k8s-admins  -> cluster-admin
k8s-viewers -> view
```

Kubernetes will see those groups as `oidc:k8s-admins` and `oidc:k8s-viewers`
after the API server is configured with `--oidc-groups-prefix=oidc:`.
