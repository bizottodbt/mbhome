# Dependency and Security Updates

This repo uses two complementary loops:

- Renovate opens pull requests for declarative dependency updates.
- Trivy scans the repo and the currently running cluster images for high and critical findings.

Renovate is the update engine. Trivy is the safety net. Merging a Renovate PR
still means Flux applies the change only after it lands on `main`.

## Renovate PRs

Install the Renovate GitHub App for the repository. No long-lived repo token is
needed in this repo when using the hosted app.

Renovate reads [`renovate.json`](../renovate.json) and opens PRs for:

- Flux `HelmRelease` chart versions
- Kubernetes workload image tags and digests
- Docker Compose image tags and digests
- Terraform providers and modules
- GitHub Actions
- Explicit bootstrap version variables annotated in the `Makefile`

Container images are digest-pinned by Renovate where possible. This keeps tags
human-readable while making the exact image content reviewable.

Major container image updates require approval from the Renovate Dependency
Dashboard before PR creation. Bootstrap tools such as Cilium, Gateway API, and
cert-manager CRDs also require dashboard approval because they can affect the
cluster before Flux is fully healthy.

## What Renovate Does Not Own

Some files are intentionally ignored:

- `kubernetes/clusters/mbhome/flux-system/gotk-components.yaml`
- generated Talos `controlplane.yaml`
- generated Talos `worker.yaml`

Upgrade Flux controllers with the Flux bootstrap/update flow, not by editing
generated controller image tags directly.

Upgrade Talos with the rolling process in
[`docs/operations-upgrades.md`](operations-upgrades.md). Do not treat generated
Talos machine configs as normal dependency manifests.

## CVE Scans

GitHub Actions runs `.github/workflows/dependency-security.yml` on PRs, pushes
to `main`, weekly schedule, and manual dispatch. The workflow uploads SARIF to
GitHub code scanning and fails on unfixed high or critical findings that Trivy
can detect in repo files.

Run the same repository scan locally:

```bash
make security-scan-repo
```

The local targets use a locally installed `trivy` binary when available. If
`trivy` is not installed, they fall back to `docker run` using
`aquasec/trivy:0.70.0`. Set `CONTAINER_RUNTIME=podman` if using Podman.

Scan the images that are actually running in the cluster:

```bash
make security-scan-cluster-images
```

The cluster image scan pulls and scans every unique init container and container
image currently referenced by running pods. It is slower than the repository
scan, but it answers the practical question: "what is live right now?"

## Review Flow

1. Open the Renovate Dependency Dashboard.
2. Approve major or bootstrap updates only when ready to test them.
3. Let Renovate open the PR.
4. Review release notes for Helm chart major versions and Kubernetes operators.
5. Confirm the Trivy workflow is clean, or consciously accept documented risk.
6. Merge to `main`.
7. Reconcile Flux:

   ```bash
   make flux-reconcile
   make flux-status
   ```

8. Check the affected component status target, for example:

   ```bash
   make cert-manager-status
   make dex-status
   make monitoring-status
   ```

## Notes

Latest is not the same as safe. Prefer explicit versions, digest-pinned images,
and small reviewable PRs. If a vendor publishes a fixed image under the same tag,
the digest update PR is the part that makes the change visible.
