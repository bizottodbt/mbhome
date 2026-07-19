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

Before the default `VaultAuth` can authenticate, bootstrap Vault's Kubernetes
auth method:

```bash
make vault-secrets-operator-bootstrap
```

That target logs in interactively to Vault, enables/configures Kubernetes auth,
creates the `vault-secrets-operator` policy, and binds it to the
`vault-sync` service account in the `vault-secrets-operator` namespace.

The initial policy is read-only and scoped to future platform/application paths:

```text
kv/platform/*
kv/apps/*
```

Status:

```bash
make vault-secrets-operator-status
```

Existing bootstrap Kubernetes Secrets remain managed by the current Make targets
until the matching Vault KV entries and `VaultStaticSecret` resources are added.
