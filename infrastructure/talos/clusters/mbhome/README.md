# mbhome Talos Cluster

This directory contains committed Talos machine-config patches and ignored
generated cluster material.

Committed:

- `patches/controlplane.yaml`
- `patches/worker.yaml`
- `patches/nodes/*.yaml`

Generated and ignored:

- `secrets.yaml`
- `controlplane.yaml`
- `worker.yaml`
- `nodes/*.yaml`
- `talosconfig`
- `kubeconfig`

Start with the single VM workflow in the root `README.md`. Once the VM boots
the Talos ISO and receives an IP address, generate and apply the first
control-plane config with the `talos-*` Make targets.

Role patches hold settings shared by all control-plane or worker nodes,
including the AD DNS nameservers used by Talos. Node patches hold per-node
identity, such as `HostnameConfig`. `make talos-gen-config` combines them into
ignored files under `nodes/`.
