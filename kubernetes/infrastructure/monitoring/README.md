# Monitoring

This directory installs `kube-prometheus-stack` through Flux.

It provides:

- Prometheus Operator
- Prometheus
- Alertmanager
- Grafana
- kube-state-metrics
- node-exporter
- default Kubernetes dashboards and alert rules

Grafana, Prometheus, and Alertmanager are exposed internally through the Cilium
Gateway:

```text
https://grafana.apps.mbhome.biz
https://prometheus.apps.mbhome.biz
https://alertmanager.apps.mbhome.biz
```

Create the Grafana admin password secret before reconciling Flux:

```bash
export GRAFANA_ADMIN_PASSWORD='...'
make monitoring-grafana-secret
```

Grafana is also configured for Dex OAuth. Create a random client secret and
store it in both places expected by Dex and Grafana:

```bash
export GRAFANA_OAUTH_CLIENT_SECRET='...'
make grafana-oauth-secret
```

Dex group mappings for Grafana:

```text
grafana-admins  -> GrafanaAdmin
grafana-editors -> Editor
grafana-viewers -> Viewer
k8s-admins      -> GrafanaAdmin
k8s-viewers     -> Viewer
```

Users outside those groups can authenticate at Dex but Grafana will reject them.
The local Grafana admin login remains enabled as a break-glass path.
Grafana requests `offline_access` and has refresh-token support enabled, so
active Grafana sessions follow the Dex refresh-token lifetime.

Then reconcile and check status:

```bash
make flux-reconcile
make monitoring-status
```

## Phone Alerts With Pushover

Alertmanager sends warning and critical alerts to Pushover. The Pushover
credentials are not stored in Git and are not created by Make as Kubernetes
Secrets. They live in Vault and are synced into the `monitoring` namespace by
Vault Secrets Operator.

Create a Pushover application for Alertmanager, then write the credentials to
Vault. This prompts inside the Vault pod so the token values are not committed
and do not need to be written into a Make target:

```bash
kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome \
  -n vault exec -it vault-0 -- vault login

kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome \
  -n vault exec -it vault-0 -- sh -ec '
    read -rsp "Pushover user key: " pushover_user_key
    echo
    read -rsp "Pushover app API token: " pushover_api_token
    echo
    vault kv put mbhome/apps/monitoring/pushover \
      user-key="$pushover_user_key" \
      api-token="$pushover_api_token"
  '
```

Bootstrap the monitoring namespace Vault role once:

```bash
make vault-app-namespace-bootstrap VAULT_APP_NAMESPACE=monitoring
```

Then reconcile:

```bash
make flux-reconcile
make monitoring-status
```

The synced Kubernetes Secret is:

```text
namespace: monitoring
secret: alertmanager-pushover
keys: user-key, api-token
```

Alert routing is intentionally simple:

- `severity="critical"` -> Pushover priority `1`, repeated every hour while firing
- `severity="warning"` -> Pushover priority `0`, repeated every four hours while firing
- resolved alerts are sent so the phone shows recovery too

Pushover emergency priority `2` is not used by default because it repeats until
acknowledged. Add it later only for wake-me-up alerts such as a fully unavailable
cluster or storage exhaustion.

## Cilium Network Policies

The monitoring namespace has Cilium ingress policies for:

- Grafana
- Prometheus
- Alertmanager
- kube-state-metrics

These policies keep the monitoring UIs reachable through the internal Cilium
Gateway while blocking unrelated direct pod-to-pod ingress into those workloads.
They also allow the expected internal monitoring paths:

- Grafana can query Prometheus.
- Prometheus can scrape itself and kube-state-metrics.
- Prometheus can send alerts to Alertmanager.
- Alertmanager can use its peer and metrics ports.
- Node-origin traffic is allowed for health checks and operational probes.

Prometheus egress is intentionally not restricted yet. Prometheus is designed
to scrape targets across namespaces and node endpoints, so locking down egress
should be done after observing real traffic with Hubble and adding explicit
allow rules for each scrape path.

Useful checks after policy changes:

```bash
kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome \
  -n monitoring get ciliumnetworkpolicies.cilium.io

curl -ksS https://grafana.apps.mbhome.biz/api/health
curl -ksS https://prometheus.apps.mbhome.biz/-/ready
curl -ksS https://alertmanager.apps.mbhome.biz/-/ready
```

Prometheus stores 15 days of data with a 20GB retention size on `nfs-cache`.
Grafana uses a 5Gi PVC and Alertmanager uses a 2Gi PVC.

The default Kubernetes PVC dashboards can be misleading with NFS CSI because
`kubelet_volume_stats_*` reports the backend filesystem/export statistics
instead of hard per-PVC quota statistics. This stack adds a custom dashboard in
the `MBHome` folder, `Storage / PVC Accounting`, and recording rules that show
PVC requested sizes separately from NFS backend-reported capacity, used, and
available bytes.

The custom PVC accounting rules intentionally exclude the `velero` namespace.
Velero backup activity can create short-lived backup pods and repository/cache
volumes that are noisy in storage dashboards and may keep backup storage more
active than desired.

For the current NFS-backed storage classes, the requested size is an operational
budget, not an enforced quota. Real per-PVC directory usage would require a
separate exporter that runs `du` against the NFS subdirectories.

`prometheus-node-exporter` runs in `kube-system` instead of `monitoring`
because it needs host namespaces, hostPath mounts, and a host port to collect
node-level metrics. Keeping only the node-level DaemonSet in `kube-system`
lets the rest of the monitoring stack stay under the `monitoring` namespace Pod
Security `baseline` profile.
