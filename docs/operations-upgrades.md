# Operations: Rolling OS Updates

This runbook covers patching and upgrading the node operating systems while
keeping workloads available where the platform has enough capacity:

- Proxmox VE host OS package updates.
- Talos OS upgrades for Kubernetes control-plane and worker nodes.

It does not cover Kubernetes minor-version upgrades, application upgrades,
firmware updates, or Proxmox major-version upgrades. Treat those as separate
maintenance plans with their own release notes and rollback testing.

## Principles

- Change one failure domain at a time.
- Do not update more than one Proxmox host at once.
- Do not update more than one Talos node at once.
- Keep Kubernetes control-plane quorum. With three control-plane nodes, upgrade
  only one control-plane node at a time and wait for health to return before the
  next one.
- Prefer live migration for Proxmox guests on shared storage.
- Prefer Kubernetes drain for Talos node OS work.
- Respect PodDisruptionBudgets. If a drain blocks, fix capacity or disruption
  policy intentionally instead of forcing it by habit.
- Keep Flux, Cilium, DNS, storage, Dex, Vault, and monitoring healthy before
  starting. If the platform is already unstable, patching should wait unless the
  patch is the fix.

## Common Preflight

Run these from the workstation before any maintenance:

```bash
git status --short
make flux-status
make talos-health TALOS_NODE=<healthy-control-plane-ip> TALOS_ENDPOINT=<healthy-control-plane-ip>
kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome get nodes -o wide
kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome get pods -A -o wide
kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome get pdb -A
```

Then check Proxmox from any cluster node:

```bash
pvecm status
pvesm status
pveversion -v
```

Do not continue if:

- Proxmox quorum is not healthy.
- Shared VM storage is missing or degraded.
- The Kubernetes API is not reachable.
- Any control-plane node is already down.
- A stateful workload is unhealthy before the maintenance starts.

## Proxmox VE OS Patching

Use this for normal Debian/Proxmox package patches on each hypervisor.

### 1. Pick One Proxmox Node

Start with the least critical or least loaded host. If a third Proxmox node is
available, keep enough spare CPU and memory on the other two hosts to receive
the guests.

Map the guests running on the node:

```bash
qm list
pvesh get /nodes/$(hostname)/qemu --output-format yaml
```

For Talos VMs, also check Kubernetes placement:

```bash
kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome get nodes -o wide
kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome get pods -A -o wide
```

### 2. Evacuate Guests

If the VM disks are on shared Proxmox storage, live migrate guests to another
host:

```bash
qm migrate <vmid> <target-proxmox-node> --online 1 --with-local-disks 0
```

The Proxmox UI can do the same from VM -> Migrate. Prefer the UI if you want to
see preflight warnings.

If a VM has local disks or cannot live migrate:

1. If it is a Kubernetes worker, drain the Kubernetes node first.
2. If it is a Kubernetes control-plane VM, verify that the other control-plane
   nodes are healthy before stopping it.
3. Shut down or offline-migrate only that VM.
4. Accept that workloads on that VM may have a brief interruption.

For a manual Kubernetes drain before stopping a Talos VM:

```bash
kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome cordon <talos-node-name>
kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome drain <talos-node-name> --ignore-daemonsets --timeout=10m
```

If the drain fails because a pod uses `emptyDir`, decide whether that pod can
lose ephemeral data. Only then add `--delete-emptydir-data`. After the VM is
back and healthy, return it to service:

```bash
kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome uncordon <talos-node-name>
```

If Proxmox HA is enabled later, place the node into HA maintenance before the
patch. Do not rely on HA failover as the normal patching method; planned
migration is cleaner than crash-style failover.

Verify the node is empty enough to patch:

```bash
qm list
```

### 3. Install Updates

On the selected Proxmox node:

```bash
sudo apt update
sudo apt list --upgradable
sudo apt full-upgrade
```

Use `apt full-upgrade`, not plain `apt upgrade`, so Proxmox/Debian dependency
changes can be resolved correctly.

If the update includes a kernel, Proxmox, QEMU, systemd, firmware, or network
package, plan a reboot.

To check whether the host is likely running an older kernel than the newest
installed kernel:

```bash
running_kernel="$(uname -r)"
newest_kernel="$(ls -1 /boot/vmlinuz-* 2>/dev/null | sed 's|/boot/vmlinuz-||' | sort -V | tail -1)"
printf 'running kernel:  %s\nnewest kernel:   %s\n' "$running_kernel" "$newest_kernel"
test "$running_kernel" = "$newest_kernel" && echo "kernel reboot not required" || echo "reboot required for newest kernel"
```

Also check whether deleted libraries or binaries are still held open by running
processes:

```bash
sudo lsof +L1
```

If `needrestart` is installed, it gives a clearer summary:

```bash
sudo needrestart
```

When in doubt after Proxmox or kernel package updates, reboot the node after
guests have been migrated away. A clean planned reboot is usually safer than
leaving a hypervisor half-updated.

### 4. Reboot One Host

```bash
sudo systemctl reboot
```

Wait for the host to return before touching the next node.

### 5. Validate The Host

After the host is back:

```bash
pvecm status
pvesm status
pveversion -v
systemctl --failed
journalctl -p err -b --no-pager
```

Storage checks matter in this lab because VM disks live on NFS-backed Proxmox
storage:

```bash
pvesm status
showmount -e <unraid-storage-ip>
```

If the baseline owns bridge, storage, or cluster configuration and you suspect
configuration drift, run it only for the node being checked:

```bash
make proxmox-baseline LIMIT=<proxmox-hostname>
```

Do not run cluster-wide maintenance while a node is still booting or storage is
still unavailable.

### 6. Return Or Rebalance Guests

Either leave guests where they landed, or live migrate them back after the node
is healthy:

```bash
qm migrate <vmid> <patched-proxmox-node> --online 1 --with-local-disks 0
```

Check Kubernetes again if Talos VMs moved:

```bash
make talos-health TALOS_NODE=<healthy-control-plane-ip> TALOS_ENDPOINT=<healthy-control-plane-ip>
kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome get nodes -o wide
```

Repeat this full sequence for the next Proxmox node.

## Talos OS Upgrades

Talos upgrades happen from the installed node. Changing the Terraform
`talos_iso_url` only changes the installer ISO used for new installs; it does
not patch an already installed Talos node.

The Makefile wraps the Talos upgrade command:

```bash
make talos-upgrade-plan \
  TALOS_NODE=<target-node-ip> \
  TALOS_ENDPOINT=<healthy-control-plane-ip> \
  TALOS_UPGRADE_VERSION=vX.Y.Z

make talos-upgrade \
  TALOS_NODE=<target-node-ip> \
  TALOS_ENDPOINT=<healthy-control-plane-ip> \
  TALOS_UPGRADE_VERSION=vX.Y.Z \
  TALOS_UPGRADE_DRAIN=true
```

This expands to:

```bash
talosctl upgrade \
  --nodes <target-node-ip> \
  --endpoints <healthy-control-plane-ip> \
  --image ghcr.io/siderolabs/installer:vX.Y.Z \
  --drain=true \
  --wait
```

Keep `TALOS_ENDPOINT` on a healthy control-plane node that is not the node being
upgraded when possible. The Kubernetes API endpoint and the Talos machine API
are different services; the Kubernetes HAProxy endpoint is not enough unless it
also proxies the Talos machine API port.

### Recommended Talos Order

1. Upgrade one worker as a canary.
2. Wait for workloads to reschedule and health to return.
3. Upgrade the remaining workers one at a time.
4. Upgrade control-plane nodes one at a time.
5. Verify etcd and Kubernetes health after every control-plane node.

This order keeps etcd risk low and proves the new Talos version on a worker
before touching the control plane.

### Worker Node Procedure

Preflight:

```bash
make talos-version TALOS_NODE=<worker-ip> TALOS_ENDPOINT=<healthy-control-plane-ip>
kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome get pods -A -o wide --field-selector spec.nodeName=<worker-node-name>
kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome get pdb -A
```

Run the upgrade:

```bash
make talos-upgrade \
  TALOS_NODE=<worker-ip> \
  TALOS_ENDPOINT=<healthy-control-plane-ip> \
  TALOS_UPGRADE_VERSION=vX.Y.Z \
  TALOS_UPGRADE_DRAIN=true
```

Talos will cordon and drain the node when drain is enabled, reboot into the new
image, wait for the node to return, and uncordon after success.

Validate:

```bash
make talos-health TALOS_NODE=<healthy-control-plane-ip> TALOS_ENDPOINT=<healthy-control-plane-ip>
kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome get nodes -o wide
kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome get pods -A -o wide
```

If a drain blocks, inspect it instead of forcing it:

```bash
kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome describe node <worker-node-name>
kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome get events -A --sort-by=.lastTimestamp
```

Common reasons are strict PodDisruptionBudgets, single-replica stateful apps, or
pods using local ephemeral data. Fix the workload or accept a planned downtime
for that workload before proceeding.

### Control-Plane Node Procedure

Only start control-plane upgrades when all control-plane nodes are healthy:

```bash
make talos-health TALOS_NODE=<healthy-control-plane-ip> TALOS_ENDPOINT=<healthy-control-plane-ip>
kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome get nodes -l node-role.kubernetes.io/control-plane -o wide
```

Upgrade exactly one control-plane node:

```bash
make talos-upgrade \
  TALOS_NODE=<control-plane-ip> \
  TALOS_ENDPOINT=<other-healthy-control-plane-ip> \
  TALOS_UPGRADE_VERSION=vX.Y.Z \
  TALOS_UPGRADE_DRAIN=true
```

After it returns, verify etcd and Kubernetes before touching another
control-plane node:

```bash
make talos-health TALOS_NODE=<healthy-control-plane-ip> TALOS_ENDPOINT=<healthy-control-plane-ip>
kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome get nodes -o wide
kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome -n kube-system get pods -o wide
```

Do not use `--force` for routine upgrades. Save it for recovery situations after
reading the Talos release notes and understanding the rollback implications.

## Coordinating Proxmox And Talos

Because Talos nodes run as Proxmox VMs, choose the right maintenance layer:

| Maintenance | Preferred evacuation | Why |
|---|---|---|
| Patch Proxmox host | Live migrate Talos and other VMs away | Guest OS keeps running while the hypervisor reboots |
| Patch Talos worker | Talos/Kubernetes drain | Pods move to other Kubernetes nodes |
| Patch Talos control plane | One control-plane Talos upgrade at a time | Keeps etcd quorum and API availability |
| Proxmox host cannot live migrate a Talos VM | Kubernetes drain, then VM shutdown/offline migration | Keeps app pods off the VM before downtime |

Avoid doing a Proxmox host patch and a Talos OS upgrade in the same window unless
the first change is fully validated before starting the second. When something
breaks, smaller blast radius is worth the extra patience.

## Rollback And Stop Conditions

Stop the maintenance if:

- Proxmox quorum is lost.
- Shared storage disappears.
- More than one Talos control-plane node is unhealthy.
- `make talos-health` fails after a node returns.
- Flux cannot reconcile platform infrastructure after the node returns.
- Stateful workloads are stuck attaching PVCs.

For Proxmox problems, keep guests away from the affected host and troubleshoot
from the console/BMC.

For Talos problems, do not upgrade another node. Inspect the failed node:

```bash
TALOSCONFIG=infrastructure/talos/clusters/mbhome/talosconfig \
  talosctl health --nodes <node-ip> --endpoints <healthy-control-plane-ip>

TALOSCONFIG=infrastructure/talos/clusters/mbhome/talosconfig \
  talosctl logs --nodes <node-ip> --endpoints <healthy-control-plane-ip>

TALOSCONFIG=infrastructure/talos/clusters/mbhome/talosconfig \
  talosctl dmesg --nodes <node-ip> --endpoints <healthy-control-plane-ip>
```

Talos uses an A/B style upgrade process and can roll back failed upgrades, but
do not depend on rollback as a normal operating path. Treat rollback as recovery,
then pause and understand why it was needed.

## Maintenance Checklist

Copy this per maintenance window:

| Step | Node | Done | Notes |
|---|---|---|---|
| Preflight healthy | all |  |  |
| Backups checked | all |  |  |
| Guests migrated or workloads drained | node 1 |  |  |
| OS patch/upgrade applied | node 1 |  |  |
| Reboot complete | node 1 |  |  |
| Proxmox/Talos health passed | node 1 |  |  |
| Kubernetes pods healthy | node 1 |  |  |
| Flux reconciled | node 1 |  |  |
| Repeat for next node | node 2 |  |  |

## References

- Kubernetes drain command reference:
  <https://kubernetes.io/docs/reference/kubectl/generated/kubectl_drain/>
- Talos CLI upgrade reference:
  <https://www.talos.dev/latest/reference/cli/>
- Talos upgrade behavior overview:
  <https://www.talos.dev/v0.11/learn-more/upgrades/>
- Proxmox VE package repositories and update model:
  <https://github.com/proxmox/pve-docs/blob/master/pve-package-repos.adoc>
- Proxmox VE system software update command reference:
  <https://raw.githubusercontent.com/proxmox/pve-docs/master/system-software-updates.adoc>
