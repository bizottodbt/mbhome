# Velero

This directory installs Velero through Flux for Kubernetes resource and volume
backup.

Velero stores backups in the external backup-only MinIO S3-compatible endpoint:

```text
https://s3-backup.mbhome.biz
```

The bucket expected by the HelmRelease is:

```text
mbhome-kubernetes-backups
```

Create the bucket and a MinIO-local Velero identity before reconciling Velero.

## MinIO Setup

Use a MinIO-local account for the backup service. This avoids making cluster
restore depend on Dex, AD, or OIDC availability. Dex/OIDC can still be added
later for human MinIO access.

Install the MinIO client, `mc`, on an admin workstation or use it from a
temporary container.

Authenticate to the backup MinIO instance with its root credentials:

```bash
export MINIO_BACKUP_ROOT_USER='...'
export MINIO_BACKUP_ROOT_PASSWORD='...'

mc alias set backup-mbhome \
  https://s3-backup.mbhome.biz \
  "$MINIO_BACKUP_ROOT_USER" \
  "$MINIO_BACKUP_ROOT_PASSWORD"

mc admin info backup-mbhome
```

Create the Velero bucket:

```bash
mc mb --ignore-existing backup-mbhome/mbhome-kubernetes-backups
```

Create a least-privilege policy for the bucket:

```bash
cat > /tmp/velero-minio-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetBucketLocation",
        "s3:ListBucket",
        "s3:ListBucketMultipartUploads"
      ],
      "Resource": [
        "arn:aws:s3:::mbhome-kubernetes-backups"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:AbortMultipartUpload",
        "s3:DeleteObject",
        "s3:GetObject",
        "s3:ListMultipartUploadParts",
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws:s3:::mbhome-kubernetes-backups/*"
      ]
    }
  ]
}
EOF

mc admin policy create backup-mbhome velero-backup /tmp/velero-minio-policy.json
```

Create a local MinIO parent user for Velero:

```bash
export VELERO_MINIO_USER='velero'
export VELERO_MINIO_PASSWORD="$(openssl rand -base64 48)"

mc admin user add \
  backup-mbhome \
  "$VELERO_MINIO_USER" \
  "$VELERO_MINIO_PASSWORD"

mc admin policy attach \
  backup-mbhome \
  velero-backup \
  --user "$VELERO_MINIO_USER"
```

The parent user's access key and secret key can be used directly for Velero:

```bash
export VELERO_S3_ACCESS_KEY_ID="$VELERO_MINIO_USER"
export VELERO_S3_SECRET_ACCESS_KEY="$VELERO_MINIO_PASSWORD"
make velero-s3-secret
```

If you prefer a separate rotatable access key under that parent user, generate
one with:

```bash
mc admin accesskey create \
  backup-mbhome \
  "$VELERO_MINIO_USER" \
  --name velero-kubernetes-backups \
  --description "Velero backups for the mbhome Kubernetes cluster"
```

Use the returned access key and secret key for:

```bash
export VELERO_S3_ACCESS_KEY_ID='returned-access-key'
export VELERO_S3_SECRET_ACCESS_KEY='returned-secret-key'
make velero-s3-secret
```

Keep the root credentials, parent user password, and generated access keys
outside Git. Store them in your password manager or Vault once Vault is part of
the restore plan.

## Spinning Disk Notes

The `backup-mbhome` MinIO alias points at a backup-only MinIO instance backed by
slower spinning storage. If the disk does not spin down when idle, check these
common wake-up sources:

- HAProxy health checks hit `/minio/health/live` repeatedly. If the disk wakes
  only because of checks, increase the HAProxy backend check interval or remove
  active checks for the backup endpoint.
- MinIO has a built-in object scanner for usage, lifecycle, replication, and
  healing work. Slow it down for backup-only storage:

  ```bash
  mc admin config set backup-mbhome scanner delay=30.0 max_wait=5m
  mc admin service restart backup-mbhome
  ```

- Avoid aggressive Prometheus scraping of MinIO metrics on the backup instance.
  Metrics collection can turn an otherwise idle disk into a periodically active
  one.
- Keep MinIO config, Docker writable layers, and logs on cache/appdata if
  possible. Only the object data path should target the spinning backup disk.
- Avoid browsing the MinIO console while testing spin-down. The console can
  poll/list state and make it look like MinIO itself is busy.
- Check Unraid-side background activity too: mover, parity check, share scans,
  plugins, filesystem indexing, and SMB/NFS exports can all wake the disk
  independently of MinIO.

MinIO exposes unauthenticated health endpoints under `/minio/health/`, and its
scanner/heal behavior is configurable with `mc admin config set`. See:

```text
https://minio.community/community/minio-object-store/operations/monitoring/healthcheck-probe.html
https://min.io/docs/minio/kubernetes/upstream/operations/concepts/scanner.html
https://github.com/minio/minio/blob/master/docs/config/README.md
```

## Credentials

Create the S3 credentials secret before reconciling Flux:

```bash
export VELERO_S3_ACCESS_KEY_ID='...'
export VELERO_S3_SECRET_ACCESS_KEY='...'
make velero-s3-secret
```

The secret is stored in Kubernetes as `velero/velero-s3-credentials`. It is not
committed to Git.

## Backups

Velero creates one scheduled backup:

```text
daily-cluster -> 03:00 every day, retained for 30 days
```

The backup includes Kubernetes resources and uses filesystem backup for pod
volumes. This is the right generic path for NFS-backed PVCs, but it is not a
replacement for app-aware backups of databases or Vault.

Use these targets after Flux reconciles:

```bash
make velero-status
make velero-backup
```

`make velero-backup` creates a manual backup using the same S3 location and
filesystem-backup behavior as the scheduled backup.

## Restore Notes

Do not treat a green backup as proven until a restore drill has been run.

Recommended restore testing path:

1. Restore a small stateless namespace.
2. Restore a test PVC-backed workload.
3. Separately validate app-aware restores for CloudNativePG and Vault.
