# Dex

Dex bridges Microsoft AD DS LDAP to Kubernetes OIDC.

This deployment is internal-only:

```text
https://dex.apps.mbhome.biz
```

Dex currently runs one replica because the deployment uses `storage.type:
memory`. Multiple replicas with memory storage can split one browser login flow
across pods and return `Bad Request: Requested resource does not exist`.

The AD connector uses LDAPS on port `636`. It currently skips certificate
verification while the DCs use lab self-signed LDAPS certificates; replace that
with `rootCAData` after AD CS issues trusted DC certificates.

Token lifetimes are set explicitly:

```text
ID token: 1 hour
Refresh token idle lifetime: 7 days
Refresh token absolute lifetime: 30 days
```

Because Dex still uses memory storage, cached refresh sessions are lost when the
Dex pod restarts. Move Dex to a persistent backend before depending on long
sessions.

Create the LDAP bind secret before Flux reconciles Dex:

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

The repo includes a credential-free OIDC kubeconfig template at
`kubernetes/clusters/mbhome/kubeconfig.oidc.yaml`. Install it into your home
directory for day-to-day access:

```bash
make kubernetes-oidc-context
export KUBECONFIG="${HOME}/.kube/mbhome-oidc"
kubectl auth whoami
```

`kubectl auth whoami` invokes `kubectl oidc-login` when no valid token is
cached.

Or merge the OIDC context into the default kubeconfig and select it:

```bash
make kubernetes-oidc-merge-context
unset KUBECONFIG
kubectl auth whoami
```

If `KUBECONFIG` is still exported, plain `kubectl` keeps using that file
instead of the merged default `~/.kube/config`.

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
