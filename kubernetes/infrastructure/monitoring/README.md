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

Then reconcile and check status:

```bash
make flux-reconcile
make monitoring-status
```

Prometheus stores 15 days of data with a 20GB retention size on `nfs-cache`.
Grafana uses a 5Gi PVC and Alertmanager uses a 2Gi PVC.
