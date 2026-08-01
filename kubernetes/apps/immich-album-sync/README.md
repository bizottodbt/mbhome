# Immich Album Sync

This app runs a Kubernetes `CronJob` every six hours to keep a target Immich
album populated with assets matching a person search.

The CronJob runs both scripts:

```text
count-script.py
sync-script.py
```

Non-secret settings live in `kustomization.yaml` as `immich-album-sync-settings`
ConfigMap literals:

```text
IMMICH_INSTANCE_URL=https://immich.mbhome.biz/api/
IMMICH_PERSON_NAME=Mikaela Bizotto Trinconi
IMMICH_ALBUM_NAME=Mimi ❤️
IMMICH_CREATED_AFTER=""
```

API keys are synced from Vault by Vault Secrets Operator.

Bootstrap the namespace-scoped Vault access:

```bash
make vault-app-namespace-bootstrap VAULT_APP_NAMESPACE=immich-album-sync
```

Seed the API keys in Vault:

```bash
kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome \
  -n vault exec -it vault-0 -- vault login

kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome \
  -n vault exec vault-0 -- \
  vault kv put mbhome/apps/immich-album-sync \
    IMMICH_API_KEY_DENIS='key-one' \
    IMMICH_API_KEY_MARTA='key-two'
```

Each Vault key whose name starts with `IMMICH_API_KEY_` is treated as one Immich
API key. This lets you rotate or remove one account independently:

```bash
kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome \
  -n vault exec vault-0 -- \
  vault kv patch mbhome/apps/immich-album-sync \
    IMMICH_API_KEY_DENIS='new-key'
```

Each Immich API key needs enough permissions to search people/assets, list
albums, and add assets to albums. The add-assets endpoint requires
`albumAsset.create`.

Validate:

```bash
kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome \
  -n immich-album-sync get cronjob,jobs,pods,vaultauth,vaultstaticsecret,secret
```
