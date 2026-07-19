# Vault

This directory installs HashiCorp Vault through Flux using the official Helm
chart.

The first deployment is intentionally conservative:

```text
mode: HA Raft
replicas: 1
storage: nfs-cache
ui: https://vault.apps.mbhome.biz
```

This keeps the Vault configuration shaped like the future HA deployment while
avoiding quorum and unseal complexity on the first pass. After init, unseal, and
backup procedures are understood, scale Vault to three replicas and join the
additional Raft peers.

Vault starts uninitialized and sealed. That is expected.

Check deployment state:

```bash
make vault-status
```

The internal Gateway routes `vault.apps.mbhome.biz` to the chart's
`vault-active` service. That service follows the active Vault Raft leader and is
the right target when the deployment later grows beyond one replica.

Initialize Vault once. This prints the unseal keys and initial root token one
time:

```bash
make vault-init
```

Store the unseal keys and initial root token outside Git before closing the
terminal. The default init settings are:

```text
key shares: 5
key threshold: 3
```

Override them only if you intentionally want a different Shamir key ceremony:

```bash
make vault-init VAULT_KEY_SHARES=7 VAULT_KEY_THRESHOLD=4
```

Unseal after initialization:

```bash
make vault-unseal
```

The target prompts for `VAULT_UNSEAL_STEPS`, which defaults to `3`, matching the
recommended init threshold in this repo. Override it if you initialized Vault
with a different threshold:

```bash
make vault-unseal VAULT_UNSEAL_STEPS=5
```

After logging in with the root token, enable audit logging to the mounted audit
PVC:

```bash
make vault-bootstrap
```

That target prompts for the initial root token, enables file audit logging, and
enables the initial KV v2 engine for mbhome platform secrets. The defaults are:

```text
audit path: /vault/audit/vault-audit.log
KV v2 mount: kv/
```

The root token is used interactively through the Vault CLI and the CLI token file
is removed from the pod at the end of the target.

The full first-run flow is:

```bash
make vault-status
make vault-init
make vault-unseal
make vault-bootstrap
make vault-status
```

After the final status check, Vault should report:

```text
Initialized true
Sealed false
```

Dex provides the human login path for Vault. Create a random OAuth client
secret locally, store it in the Dex namespace, reconcile Dex, and then bootstrap
Vault's OIDC auth method:

```bash
export VAULT_OIDC_CLIENT_SECRET='...'
make vault-oidc-secret
# Commit and push the Dex client change before reconciling.
make flux-reconcile
make vault-oidc-bootstrap
```

`vault-oidc-bootstrap` prompts for a Vault token with enough privilege to manage
auth methods, policies, and identity groups. Use the initial root token for the
first run, then retire it once regular admin access is proven.

The default OIDC role is named `default` and accepts both the Vault UI and CLI
callback URLs:

```text
https://vault.apps.mbhome.biz/ui/vault/auth/oidc/oidc/callback
http://localhost:8250/oidc/callback
```

AD groups are mapped through Dex group claims:

```text
vault-admins  -> vault-admin policy
vault-users   -> vault-user policy
vault-readers -> vault-reader policy
```

Users outside those groups can authenticate at Dex, but they only receive the
Vault `default` policy.

For the Vault UI, select the `oidc` auth method. The role can be left empty
because Vault is configured with `default` as the OIDC default role.

For this first stage, keep the existing Make secret targets. They remain useful
for bootstrap and break-glass until Vault Secrets Operator is deployed and the
current secrets are migrated into Vault.

Vault's Kubernetes auth method is used by Vault Secrets Operator. The repo grants
the Vault server service account TokenReview access through
`kubernetes-auth-rbac.yaml`, then the auth method is configured interactively:

```bash
make vault-secrets-operator-bootstrap
make vault-secrets-operator-status
```
