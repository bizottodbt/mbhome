# Cloudflare Tunnel

`cloudflared` runs inside Kubernetes and establishes outbound-only connections
to Cloudflare. Nothing in this namespace exposes an inbound Service.

Use Cloudflare Tunnel as an explicit allowlist for apps that should be reachable
from the internet. Keep the Kubernetes Gateway and internal AD DNS wildcard on
the normal app domain:

```text
*.apps.mbhome.biz -> 10.20.30.200
```

Do not publish a public wildcard for `*.apps.mbhome.biz`. Add only selected
hostnames, one by one, in Cloudflare.

## Bootstrap

Create a tunnel in Cloudflare Zero Trust:

1. Go to Zero Trust -> Networks -> Tunnels.
2. Create a Cloudflared tunnel.
3. Copy the tunnel token.
4. Store it in Kubernetes:

```bash
export CLOUDFLARED_TUNNEL_TOKEN='...'
make cloudflared-token-secret
make flux-reconcile
make cloudflared-status
```

The token is stored as:

```text
cloudflared/cloudflared-tunnel-token
```

It is not committed to Git.

## Expose An App

In Kubernetes, the app keeps its normal internal route:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: whoami
  namespace: whoami
spec:
  parentRefs:
    - name: internal
      namespace: gateway-system
      sectionName: https
  hostnames:
    - whoami.apps.mbhome.biz
  rules:
    - backendRefs:
        - name: whoami
          port: 80
```

In Cloudflare Tunnel, add a public hostname:

```text
Hostname: whoami.apps.mbhome.biz
Service:  https://10.20.30.200
```

Set the origin request options for that hostname:

```text
HTTP Host Header:  whoami.apps.mbhome.biz
Origin Server Name: whoami.apps.mbhome.biz
No TLS Verify: disabled
```

That preserves the original hostname so Cilium Gateway can match the HTTPRoute,
and keeps TLS verification enabled against the wildcard certificate issued by
cert-manager.

## Access Policy

For every public hostname, create a matching Cloudflare Access self-hosted
application. Recommended defaults:

- Require login for all internet-exposed admin or personal apps.
- Allow only named users or groups.
- Require MFA for sensitive apps such as Vault, Grafana, Proxmox, Unraid, and
  Home Assistant.
- Keep unauthenticated access for deliberately public apps only.

## Validate

```bash
make cloudflared-status
curl -Ik https://whoami.apps.mbhome.biz
```

From the LAN, AD DNS sends the hostname directly to the Cilium Gateway. From the
internet, Cloudflare sends the selected hostname through the tunnel.
