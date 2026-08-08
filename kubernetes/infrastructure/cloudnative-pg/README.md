# CloudNativePG

CloudNativePG installs the PostgreSQL operator used by platform components that
need a durable SQL backend.

The operator is installed by Flux before database clusters are reconciled. Keep
database `Cluster` resources in a later Flux layer so their CRDs already exist.

## Cilium Network Policy

The CloudNativePG operator has a workload-scoped Cilium policy:

- Kubernetes admission traffic can reach the webhook on `9443`. On Talos/Cilium
  this traffic can be classified as `kube-apiserver`, `host`, or `remote-node`,
  so all three are allowed on the webhook port.
- Prometheus can scrape operator metrics on `8080`.
- The operator can reach CoreDNS and the Kubernetes API on `443` and Talos
  control-plane port `6443`.
- The operator can reach CloudNativePG-managed PostgreSQL instance pods on
  `5432` for database reconciliation and `8000` for the instance manager status
  API, including `/pg/status`.

If a database cluster reports `Instance Status Extraction Error` with a timeout
to `https://<pod-ip>:8000/pg/status`, verify that this policy has been applied.

Application clients need their own namespace policies for database access. This
policy only covers the operator in `cnpg-system`.
