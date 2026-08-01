# Vault Secrets Operator

This installs HashiCorp Vault Secrets Operator through Flux.

The operator is the bridge from Vault KV paths to Kubernetes `Secret` objects.
It does not migrate existing secrets by itself; each synced secret is declared
later with a `VaultStaticSecret`, `VaultDynamicSecret`, or related
`secrets.hashicorp.com/v1beta1` resource.

This first pass creates:

```text
namespace: vault-secrets-operator
VaultConnection/default -> http://vault-active.vault.svc.cluster.local:8200
VaultAuth/default      -> Kubernetes auth role vault-secrets-operator
```

Application namespaces should define their own local `VaultAuth/default` and
`vault-sync` ServiceAccount. The app-level Vault role should grant only the
namespace's own path:

```text
mbhome/apps/<namespace>
```

For example, ImmichFrame uses `mbhome/apps/immichframe`.

Bootstrap an app namespace with:

```bash
make vault-app-namespace-bootstrap VAULT_APP_NAMESPACE=immichframe
```

That creates a Vault policy and Kubernetes auth role named
`app-<namespace>`, bound to the `vault-sync` ServiceAccount in that namespace.
The resulting access is limited to:

```text
mbhome/apps/<namespace>
mbhome/apps/<namespace>/*
```

Before the default `VaultAuth` can authenticate, bootstrap Vault's Kubernetes
auth method:

```bash
make vault-secrets-operator-bootstrap
```

That target logs in interactively to Vault, enables/configures Kubernetes auth,
creates the `vault-secrets-operator` policy, and binds it to the
`vault-sync` service account in the `vault-secrets-operator` namespace.

The initial shared policy is read-only and scoped to platform paths:

```text
mbhome/platform/*
```

The mount path comes from `VAULT_KV_MOUNT`, which defaults to `mbhome`.

Status:

```bash
make vault-secrets-operator-status
```

Existing bootstrap Kubernetes Secrets remain managed by the current Make targets
until the matching Vault KV entries and `VaultStaticSecret` resources are added.
