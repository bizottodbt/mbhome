# LLM

This app runs a local CPU-friendly LLM stack:

- Ollama serves local models inside the cluster.
- Open WebUI provides the browser chat UI at `https://llm.apps.mbhome.biz`.
- Future automation can call Ollama directly at `http://ollama.llm.svc.cluster.local:11434`.

Ollama stores downloaded models in the `ollama-models` PVC. Open WebUI stores users,
chats, and settings in the `open-webui-data` PVC.

## Bootstrap

Create the Vault policy and Kubernetes auth role for the namespace:

```bash
make vault-app-namespace-bootstrap VAULT_APP_NAMESPACE=llm
```

Seed the Open WebUI secret key in Vault:

```bash
export OPEN_WEBUI_SECRET_KEY="$(openssl rand -base64 48)"

kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome \
  -n vault exec -it vault-0 -- vault login

kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome \
  -n vault exec vault-0 -- \
  vault kv put mbhome/apps/llm/open-webui WEBUI_SECRET_KEY="$OPEN_WEBUI_SECRET_KEY"
```

Reconcile and wait for the app:

```bash
make flux-reconcile
make llm-status
```

## Models

Pull the first model explicitly after Ollama is running. A small coding model is a
good CPU-only starting point:

```bash
make llm-model-pull LLM_MODEL=qwen2.5-coder:3b
make llm-models
```

The first pull can take a while. The model is stored in the `ollama-models` PVC and
survives pod restarts.

Open `https://llm.apps.mbhome.biz` after the model is present. Open WebUI creates
its initial admin user during first login; later this can be connected to Dex/OIDC.
