# Apps

Flux reconciles this directory after the infrastructure layer is ready.

The initial `whoami` app is a small Gateway API smoke test exposed only through
the internal Gateway:

```text
http://whoami.apps.mbhome.biz
https://whoami.apps.mbhome.biz
```

Validate after Flux reconciles:

```bash
kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  -n whoami get deploy,svc,httproute

curl -i http://whoami.apps.mbhome.biz
curl -Ik https://whoami.apps.mbhome.biz
```

Real apps live beside the smoke test. Current apps:

| App | URL | Notes |
| --- | --- | --- |
| Forgejo | `https://git.apps.mbhome.biz` | Internal Git service. PostgreSQL is managed by CloudNativePG, persistent data lives on `nfs-user`, Actions is enabled, and admin/OAuth/database secrets are synced from Vault. |
| ImmichFrame | `https://immichframe.apps.mbhome.biz` | Digital photo frame backed by Immich. The Immich API key is synced from Vault. |
| LLM | `https://ai.apps.mbhome.biz` | Open WebUI backed by Ollama. The WebUI secret key and OAuth client secret are synced from Vault, and models live in the Ollama PVC. |

Seed Forgejo before reconciling it:

```bash
export FORGEJO_POSTGRES_PASSWORD="$(openssl rand -hex 32)"
make forgejo-postgres-secret

make vault-app-namespace-bootstrap VAULT_APP_NAMESPACE=forgejo

make forgejo-config-secret

export FORGEJO_ADMIN_USERNAME=forgejo_admin
export FORGEJO_ADMIN_PASSWORD="$(openssl rand -base64 36)"
make forgejo-admin-secret

export FORGEJO_OAUTH_CLIENT_SECRET="$(openssl rand -hex 32)"
make forgejo-oauth-secret
```

Seed the Forgejo runner after the `forgejo-runner` namespace exists:

```bash
make flux-reconcile
make vault-app-namespace-bootstrap VAULT_APP_NAMESPACE=forgejo-runner
```

Create a runner registration token in Forgejo under
`Site Administration -> Actions -> Runners`, then store it in Vault:

```bash
export FORGEJO_RUNNER_REGISTRATION_TOKEN='...'
make forgejo-runner-registration-secret
make forgejo-runner-status
```

Seed the ImmichFrame secret before reconciling the app:

```bash
kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome \
  -n vault exec -it vault-0 -- vault login

kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome \
  -n vault exec vault-0 -- \
  vault kv put mbhome/apps/immichframe immich-api-key='<immich-api-key>'
```

Validate ImmichFrame:

```bash
make immichframe-status
```

Seed the LLM namespace and Open WebUI secret before reconciling the app:

```bash
make vault-app-namespace-bootstrap VAULT_APP_NAMESPACE=llm

export OPEN_WEBUI_SECRET_KEY="$(openssl rand -base64 48)"

kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome \
  -n vault exec -it vault-0 -- vault login

kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome \
  -n vault exec vault-0 -- \
  vault kv put mbhome/apps/llm/open-webui WEBUI_SECRET_KEY="$OPEN_WEBUI_SECRET_KEY"
```

Validate the LLM app and pull a first CPU-friendly model:

```bash
make llm-status
make llm-model-pull LLM_MODEL=qwen2.5-coder:3b
make llm-models
```
