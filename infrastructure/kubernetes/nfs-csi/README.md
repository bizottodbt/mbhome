# NFS CSI

This directory installs the upstream Kubernetes CSI NFS driver and defines two
local StorageClasses for Unraid:

- `nfs-cache`: fast 10 GbE path directly to an Unraid cache pool export,
  intended for hot or disposable persistent volumes.
- `nfs-user`: slower parity-backed Unraid user-share export, intended for more
  durable persistent volumes.

Edit `storageclasses.yaml`:

- set `server` to the Unraid 10 GbE address, for example `10.20.90.10`
- set the cache-backed `share`, for example `/mnt/cache/k8s-fast`
- set the parity-backed `share`, for example `/mnt/user/k8s-durable`

Create both paths on Unraid and export them over NFS to the Talos node subnet
before applying the StorageClasses. For the fast class, export the cache path
directly, for example `/mnt/cache/k8s-fast`, to bypass Unraid user shares and
parity/mover behavior. The CSI driver creates PVC subdirectories inside those
exports, but it does not create or export the top-level shares.

For Unraid custom cache exports, keep the export line in standard Linux exports
syntax with the options inside the client option list:

```exports
/mnt/cache/k8s-fast 10.20.90.0/24(rw,async,no_subtree_check,no_root_squash,fsid=110)
```

Do not reuse `fsid` values across exports.

Install:

```bash
make nfs-csi-helm-repo
make nfs-csi-install
make nfs-csi-storageclasses
make nfs-csi-status
```

The `nfs-cache` class uses `reclaimPolicy: Delete` and `onDelete: delete`.
The `nfs-user` class uses `reclaimPolicy: Retain` and `onDelete: retain` to
avoid accidental data deletion.
