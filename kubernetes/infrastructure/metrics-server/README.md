# Metrics Server

This directory installs `metrics-server` through Flux.

Metrics Server provides the Kubernetes Metrics API (`metrics.k8s.io`) used by:

- Headlamp usage views
- `kubectl top nodes`
- `kubectl top pods`
- HorizontalPodAutoscaler resource metrics

The release runs in `kube-system` and uses:

```yaml
args:
  - --kubelet-insecure-tls
```

That flag is used because Talos kubelet serving certificates are not currently
wired into metrics-server trust. Prometheus remains the long-term monitoring
system; metrics-server is the lightweight Kubernetes-native usage feed.

Check it with:

```bash
make metrics-server-status
```
