# Dex

Dex bridges Microsoft AD DS LDAP to Kubernetes OIDC.

This deployment is internal-only:

```text
https://dex.apps.mbhome.biz
```

Dex currently runs one replica because the deployment uses `storage.type:
memory`. Multiple replicas with memory storage can split one browser login flow
across pods and return `Bad Request: Requested resource does not exist`.

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

AD groups mapped for Kubernetes RBAC:

```text
k8s-admins  -> cluster-admin
k8s-viewers -> view
```

Kubernetes will see those groups as `oidc:k8s-admins` and `oidc:k8s-viewers`
after the API server is configured with `--oidc-groups-prefix=oidc:`.
