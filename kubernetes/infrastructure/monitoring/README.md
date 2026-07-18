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

Then reconcile and check status:

```bash
make flux-reconcile
make monitoring-status
```

Prometheus stores 15 days of data with a 20GB retention size on `nfs-cache`.
Grafana uses a 5Gi PVC and Alertmanager uses a 2Gi PVC.

`prometheus-node-exporter` runs in `kube-system` instead of `monitoring`
because it needs host namespaces, hostPath mounts, and a host port to collect
node-level metrics. Keeping only the node-level DaemonSet in `kube-system`
lets the rest of the monitoring stack stay under the `monitoring` namespace Pod
Security `baseline` profile.
