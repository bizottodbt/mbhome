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

Initialize Vault once:

```bash
kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome \
  -n vault exec vault-0 -- vault operator init -key-shares=5 -key-threshold=3
```

Store the unseal keys and initial root token outside Git.

Unseal after initialization:

```bash
kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome \
  -n vault exec -it vault-0 -- vault operator unseal
```

Run the unseal command with enough unseal keys to satisfy the threshold.

After logging in with the root token, enable audit logging to the mounted audit
PVC:

```bash
kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome \
  -n vault exec -it vault-0 -- vault login

kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome \
  -n vault exec vault-0 -- vault audit enable file file_path=/vault/audit/vault-audit.log
```

Then create the initial KV v2 engine for mbhome platform secrets:

```bash
kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome \
  -n vault exec vault-0 -- vault secrets enable -path=kv kv-v2
```

For this first stage, keep the existing Make secret targets. They remain useful
for bootstrap and break-glass until Vault Secrets Operator is deployed and the
current secrets are migrated into Vault.
