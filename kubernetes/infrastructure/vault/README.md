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

For this first stage, keep the existing Make secret targets. They remain useful
for bootstrap and break-glass until Vault Secrets Operator is deployed and the
current secrets are migrated into Vault.
