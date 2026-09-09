# Vault Transit Unseal Provider

This compose bundle runs a small standalone Vault on Unraid. It exists only to
host the `transit/autounseal` key used by the Kubernetes Vault cluster for
auto-unseal.

This does not replace the main Vault in Kubernetes. Do not store app secrets in
this Vault.

```text
Kubernetes Vault pods -> http://10.20.30.50:8200 -> transit/autounseal
```

The provider still needs to be initialized and unsealed after an Unraid reboot.
The benefit is that normal Kubernetes Vault pod restarts no longer require
manual unseal.

## Deploy

Copy this directory to persistent Unraid appdata storage, for example:

```bash
/mnt/user/appdata/vault-unseal
```

Create the local `.env` file:

```bash
cp .env.example .env
```

Start the provider:

```bash
docker compose up -d
docker compose logs -f vault-unseal
```

## Initialize

Initialize this provider once:

```bash
docker compose exec vault-unseal vault operator init -key-shares=3 -key-threshold=2
```

Store the unseal keys and root token outside Git.

Unseal it:

```bash
docker compose exec vault-unseal vault operator unseal
docker compose exec vault-unseal vault operator unseal
```

Log in with the provider root token:

```bash
docker compose exec vault-unseal vault login
```

Enable transit and create the auto-unseal key:

```bash
docker compose exec vault-unseal vault secrets enable transit
docker compose exec vault-unseal vault write -f transit/keys/autounseal
```

Create the narrow policy used by the Kubernetes Vault cluster:

```bash
docker compose exec vault-unseal sh -lc 'printf "%s\n" \
  "path \"transit/encrypt/autounseal\" {" \
  "  capabilities = [\"update\"]" \
  "}" \
  "" \
  "path \"transit/decrypt/autounseal\" {" \
  "  capabilities = [\"update\"]" \
  "}" \
  > /tmp/autounseal-policy.hcl'

docker compose exec vault-unseal vault policy write autounseal /tmp/autounseal-policy.hcl
```

Create an orphan periodic token. This token is the only value copied into the
Kubernetes cluster:

```bash
docker compose exec vault-unseal vault token create \
  -orphan \
  -period=720h \
  -policy=autounseal \
  -field=token
```

## Health

Check status:

```bash
docker compose exec vault-unseal vault status
```

Check that the provider is reachable from the LAN:

```bash
curl -sS http://10.20.30.50:8200/v1/sys/health
```

## Notes

Keep this service reachable only on trusted internal networks. The transit token
is intentionally narrow, but the service is still part of the protection chain
for the main Vault cluster.
