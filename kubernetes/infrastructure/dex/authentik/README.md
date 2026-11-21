# Authentik

Authentik is deployed in the identity stage at:

```text
https://authentik.apps.mbhome.biz
```

This initial deployment intentionally does not configure Active Directory,
Dex, applications, providers, or MFA. It provides one Authentik server, one
worker, and a dedicated two-instance CloudNativePG database.

## Required Vault secret

First bootstrap namespace-scoped Vault access:

```bash
make vault-app-namespace-bootstrap VAULT_APP_NAMESPACE=authentik
```

Write the initial configuration to `mbhome/apps/authentik/config`:

```bash
AUTHENTIK_POSTGRES_PASSWORD="$(openssl rand -base64 48 | tr -d '\n')"
AUTHENTIK_SECRET_KEY="$(openssl rand -base64 60 | tr -d '\n')"

kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome -n vault exec -it vault-0 -- vault login

kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome -n vault exec vault-0 -- \
  vault kv put mbhome/apps/authentik/config \
    username=authentik \
    password="${AUTHENTIK_POSTGRES_PASSWORD}" \
    AUTHENTIK_SECRET_KEY="${AUTHENTIK_SECRET_KEY}"

unset AUTHENTIK_POSTGRES_PASSWORD AUTHENTIK_SECRET_KEY
```

Do not rotate `AUTHENTIK_SECRET_KEY` casually because doing so invalidates
active sessions. If either secret value is intentionally changed later, restart
the server and worker after Vault Secrets Operator has synchronized it:

```bash
kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome -n authentik rollout restart \
  deployment/authentik-server deployment/authentik-worker
```

After Flux reports the identity stage ready, open the route and complete
Authentik's initial setup flow. AD and Dex integration are separate follow-up
changes.
