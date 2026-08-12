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
| ImmichFrame | `https://immichframe.apps.mbhome.biz` | Digital photo frame backed by Immich. The Immich API key is synced from Vault. |
| LLM | `https://ai.apps.mbhome.biz` | Open WebUI backed by Ollama. The WebUI secret key and OAuth client secret are synced from Vault, and models live in the Ollama PVC. |

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
