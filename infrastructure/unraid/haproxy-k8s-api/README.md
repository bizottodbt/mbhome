# HAProxy for Pre-Cluster Services

This compose bundle runs HAProxy on Unraid for services that must exist outside
Kubernetes. Keep recovery/bootstrap endpoints here, and route in-cluster
applications through Cilium Gateway API.

Initial shape:

```text
k8s-api.mbhome.biz:6443 -> Unraid HAProxy -> mbhome-talos-cp-01:6443
                                      \-> mbhome-talos-cp-02:6443
                                      \-> mbhome-talos-cp-03:6443
talos-api.mbhome.biz:50000 -> Unraid HAProxy -> mbhome-talos-cp-01:50000
                                         \-> mbhome-talos-cp-02:50000
                                         \-> mbhome-talos-cp-03:50000
https://minio.mbhome.biz -> Unraid HAProxy -> mbhome-nas-01:9000
https://minio-console.mbhome.biz -> Unraid HAProxy -> mbhome-nas-01:9001
https://unraid.mbhome.biz -> Unraid HAProxy -> mbhome-nas-01:80
https://proxmox.mbhome.biz -> Unraid HAProxy -> mbhome-proxmox-01:8006
                                          \-> mbhome-proxmox-02:8006
https://mbhome-nas-01-bmc.mbhome.biz -> Unraid HAProxy -> BMC 10.20.30.20:443
https://mbhome-proxmox-01-bmc.mbhome.biz -> Unraid HAProxy -> BMC 10.20.30.21:443
https://mbhome-proxmox-02-bmc.mbhome.biz -> Unraid HAProxy -> BMC 10.20.30.22:443
```

## Files

- `docker-compose.yml`: HAProxy container definition
- `haproxy.cfg`: TCP load balancer config for Kubernetes/Talos APIs and HTTPS
  reverse proxy config for MinIO
- `certs/`: local-only certificate mount point; do not commit private keys
- `letsencrypt/`: local-only certbot state; do not commit
- `cloudflare.ini`: local-only Cloudflare DNS API token file; do not commit
- `scripts/`: certbot renewal and optional HAProxy restart helpers

## Deploy on Unraid

Copy this directory to a persistent path on Unraid, for example:

```bash
/mnt/user/appdata/haproxy-k8s-api
```

Then start it from that directory:

```bash
docker compose up -d
```

Validate the HAProxy config:

```bash
docker compose exec haproxy haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg
```

Show logs:

```bash
docker compose logs -f
```

## Certificates

For non-Kubernetes internal endpoints, the compose bundle uses certbot with
Cloudflare DNS-01 to issue a public Let's Encrypt certificate for:

```text
mbhome.biz
*.mbhome.biz
```

Create a Cloudflare API token scoped to the `mbhome.biz` zone with:

```text
Zone / Zone / Read
Zone / DNS / Edit
```

Create the local files on Unraid:

```bash
cp .env.example .env
cp cloudflare.ini.example cloudflare.ini
```

Edit `.env` and set `CERTBOT_EMAIL`. Edit `cloudflare.ini` and set the
Cloudflare token:

```text
dns_cloudflare_api_token = replace-with-real-token
```

Lock down the token file:

```bash
chmod 600 cloudflare.ini
```

Start certbot first so it can create the HAProxy PEM:

```bash
docker compose up -d certbot
docker compose logs -f certbot
```

Certbot writes the PEM expected by HAProxy:

```text
certs/mbhome.biz.pem
```

Then start HAProxy:

```bash
docker compose up -d haproxy
docker compose exec haproxy haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg
```

The certbot container wakes up twice a day by default, runs `certbot renew`,
and rewrites `certs/mbhome.biz.pem` when the certificate changes.

HAProxy does not automatically reload certificates from disk. The conservative
default is to restart HAProxy after renewal when needed:

```bash
docker compose restart haproxy
```

If you want automatic restart after renewal, enable the optional reloader
profile:

```bash
docker compose --profile auto-reload up -d
```

That helper mounts `/var/run/docker.sock` and restarts the HAProxy container
when `certs/mbhome.biz.pem` changes. Docker socket access is powerful; leave
the profile disabled if you prefer manual restarts.

Private keys, certbot state, `.env`, and the Cloudflare token are intentionally
ignored by Git. Kubernetes-hosted apps should continue using the in-cluster
`*.apps.mbhome.biz` certificate managed by cert-manager.

## DNS

Point pre-cluster service DNS names at the Unraid IP that exposes this compose
service:

```text
k8s-api.mbhome.biz -> <unraid-ip>
talos-api.mbhome.biz -> <unraid-ip>
minio.mbhome.biz -> <unraid-ip>
minio-console.mbhome.biz -> <unraid-ip>
unraid.mbhome.biz -> <unraid-ip>
proxmox.mbhome.biz -> <unraid-ip>
mbhome-nas-01-bmc.mbhome.biz -> <unraid-ip>
mbhome-proxmox-01-bmc.mbhome.biz -> <unraid-ip>
mbhome-proxmox-02-bmc.mbhome.biz -> <unraid-ip>
```

For example, if clients should reach HAProxy over the management VLAN:

```text
k8s-api.mbhome.biz -> 10.20.30.50
talos-api.mbhome.biz -> 10.20.30.50
minio.mbhome.biz -> 10.20.30.50
minio-console.mbhome.biz -> 10.20.30.50
unraid.mbhome.biz -> 10.20.30.50
proxmox.mbhome.biz -> 10.20.30.50
mbhome-nas-01-bmc.mbhome.biz -> 10.20.30.50
mbhome-proxmox-01-bmc.mbhome.biz -> 10.20.30.50
mbhome-proxmox-02-bmc.mbhome.biz -> 10.20.30.50
```

If clients should reach it over the 10 GbE/storage VLAN:

```text
k8s-api.mbhome.biz -> 10.20.90.10
talos-api.mbhome.biz -> 10.20.90.10
minio.mbhome.biz -> 10.20.90.10
minio-console.mbhome.biz -> 10.20.90.10
unraid.mbhome.biz -> 10.20.90.10
proxmox.mbhome.biz -> 10.20.90.10
mbhome-nas-01-bmc.mbhome.biz -> 10.20.90.10
mbhome-proxmox-01-bmc.mbhome.biz -> 10.20.90.10
mbhome-proxmox-02-bmc.mbhome.biz -> 10.20.90.10
```

Pick the address that your Talos nodes, Kubernetes pods, and admin workstation
can all reach reliably.

## Talos

Use the DNS name as the Kubernetes API endpoint embedded in Talos cluster
config:

```make
TALOS_K8S_ENDPOINT := k8s-api.mbhome.biz
```

This bundle also exposes the Talos machine API on TCP/50000:

```make
TALOS_ENDPOINT := talos-api.mbhome.biz
```

For break-glass operations, keep a known-good control-plane IP available so you
can bypass HAProxy if Unraid is unavailable.

Because the Kubernetes API and Talos machine API are TCP-passed through instead
of terminated by HAProxy, their certificates must be issued by Talos with the
load-balanced DNS names as SANs. Keep these in the control-plane Talos patch:

```yaml
machine:
  certSANs:
    - talos-api.mbhome.biz
    - 10.20.30.50

cluster:
  apiServer:
    certSANs:
      - k8s-api.mbhome.biz
      - 10.20.30.50
      - 10.20.30.71
      - 10.20.30.72
      - 10.20.30.73
```

Then regenerate and reapply the Talos config:

```bash
make talos-gen-config
make talos-apply
```

## MinIO

The HTTPS frontend routes MinIO by hostname:

```text
https://minio.mbhome.biz         -> 10.20.30.50:9000
https://minio-console.mbhome.biz -> 10.20.30.50:9001
```

Configure the MinIO container on Unraid with matching external URLs when
possible:

```text
MINIO_SERVER_URL=https://minio.mbhome.biz
MINIO_BROWSER_REDIRECT_URL=https://minio-console.mbhome.biz
```

Backup clients such as Velero should use the S3 API endpoint:

```text
https://minio.mbhome.biz
```

## Management UIs

The HTTPS frontend also routes management UIs by hostname:

```text
https://unraid.mbhome.biz
https://proxmox.mbhome.biz
https://mbhome-nas-01-bmc.mbhome.biz
https://mbhome-proxmox-01-bmc.mbhome.biz
https://mbhome-proxmox-02-bmc.mbhome.biz
```

Unraid is proxied to HTTP port `80` because HAProxy owns external TLS on port
`443`. Keep Unraid `Use SSL/TLS` disabled or move Unraid's own HTTPS listener
away from `443` so it does not conflict with this container.

`proxmox.mbhome.biz` balances across the Proxmox cluster nodes with source
stickiness. This gives one stable browser endpoint while keeping individual
nodes available behind the cluster.

BMC web UIs are proxied individually. Basic web access should work, but remote
console, virtual media, and firmware workflows may still need direct BMC access
because many BMCs use vendor-specific websocket, Java, media, or TLS behavior.

## Verification

From your workstation:

```bash
nc -vz k8s-api.mbhome.biz 6443
nc -vz talos-api.mbhome.biz 50000
curl -Ik https://minio.mbhome.biz/minio/health/live
curl -Ik https://minio-console.mbhome.biz
curl -Ik https://unraid.mbhome.biz
curl -Ik https://proxmox.mbhome.biz
curl -Ik https://mbhome-proxmox-01-bmc.mbhome.biz
```

After `talos-kubeconfig`, verify Kubernetes through the HAProxy endpoint:

```bash
KUBECONFIG=infrastructure/talos/clusters/mbhome/kubeconfig kubectl get nodes -o wide
```

HAProxy stats are exposed at:

```text
http://<unraid-ip>:8404/
```

## Updating Control Planes

When control-plane nodes are added, removed, or renumbered, update their
Kubernetes API and Talos machine API `server` lines in `haproxy.cfg`, then
reload:

```bash
docker compose restart haproxy
```

Keep at least one break-glass Talos/Kubernetes admin config outside the
cluster. If this HAProxy instance is unavailable, clients using
`k8s-api.mbhome.biz` cannot reach the Kubernetes API.
