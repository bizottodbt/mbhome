# HAProxy for Talos Kubernetes API

This compose bundle runs a simple TCP HAProxy on Unraid for the Talos
Kubernetes API endpoint.

Initial shape:

```text
k8s-api.mbhome.biz:6443 -> Unraid HAProxy -> mbhome-talos-cp-01:6443
```

Later HA shape:

```text
k8s-api.mbhome.biz:6443 -> Unraid HAProxy -> mbhome-talos-cp-01:6443
                                      \-> mbhome-talos-cp-02:6443
                                      \-> mbhome-talos-cp-03:6443
```

## Files

- `docker-compose.yml`: HAProxy container definition
- `haproxy.cfg`: TCP load balancer config for Kubernetes API

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
docker compose exec haproxy-k8s-api haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg
```

Show logs:

```bash
docker compose logs -f
```

## DNS

Point the Kubernetes API DNS name at the Unraid IP that exposes this compose
service:

```text
k8s-api.mbhome.biz -> <unraid-ip>
```

For example, if clients should reach HAProxy over the management VLAN:

```text
k8s-api.mbhome.biz -> 10.20.30.50
```

If clients should reach it over the 10 GbE/storage VLAN:

```text
k8s-api.mbhome.biz -> 10.20.90.10
```

Pick the address that your Talos nodes and admin workstation can both reach
reliably.

## Talos

Use the DNS name as the Kubernetes API endpoint embedded in Talos cluster
config:

```make
TALOS_K8S_ENDPOINT := k8s-api.mbhome.biz
```

Keep `TALOS_ENDPOINT` pointed at a real Talos control-plane IP unless this
HAProxy instance also exposes the Talos machine API on TCP/50000.

Then regenerate and reapply the Talos config:

```bash
make talos-gen-config
make talos-apply
```

## Verification

From your workstation:

```bash
nc -vz k8s-api.mbhome.biz 6443
```

After `talos-kubeconfig`, verify Kubernetes through the HAProxy endpoint:

```bash
KUBECONFIG=infrastructure/talos/clusters/mbhome/kubeconfig kubectl get nodes -o wide
```

HAProxy stats are exposed at:

```text
http://<unraid-ip>:8404/
```

## Adding Control Planes

When `mbhome-talos-cp-02` and `mbhome-talos-cp-03` exist, uncomment their
`server` lines in `haproxy.cfg`, then reload:

```bash
docker compose restart haproxy-k8s-api
```

Keep at least one break-glass Talos/Kubernetes admin config outside the
cluster. If this HAProxy instance is unavailable, clients using
`k8s-api.mbhome.biz` cannot reach the Kubernetes API.
