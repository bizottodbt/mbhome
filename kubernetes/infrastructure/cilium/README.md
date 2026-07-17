# Cilium

This directory contains the Helm values for Cilium on the mbhome Talos cluster.

Cilium is installed manually before Flux because Flux controllers need a
working CNI to run. Keep the values here so the bootstrap command and the
steady-state cluster layout live under the same Kubernetes tree.

The Talos machine-config patches disable the default CNI and kube-proxy:

```yaml
cluster:
  network:
    cni:
      name: none
  proxy:
    disabled: true
```

Install after `make talos-bootstrap` and `make talos-kubeconfig`:

```bash
make gateway-api-crds-install
make cilium-helm-repo
make cilium-install
make cilium-status
```

The values use:

- Kubernetes IPAM
- Cilium kube-proxy replacement
- Cilium Gateway API support
- Cilium L2 announcements for LoadBalancer IPs on the LAN
- KubePrism on `localhost:7445`
- Talos cgroup host root at `/sys/fs/cgroup`
- Cilium capabilities without `SYS_MODULE`

Flux reconciles the Cilium LB IPAM pool and L2 announcement policy in this
directory. The initial pool is `10.20.30.200-10.20.30.209`, with the internal
Gateway pinned to `10.20.30.200`. L2 announcements are sent on `ens18`, the
Talos VM management NIC on the `10.20.30.0/24` LAN.

Keep `operator.replicas` at `1` for the initial single-control-plane cluster.
Raise it after adding more control-plane nodes.
