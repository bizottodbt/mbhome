# cert-manager

cert-manager issues the internal `*.apps.mbhome.biz` wildcard certificate with
Let's Encrypt DNS-01 validation through Cloudflare.

Create the Cloudflare token secret before reconciling cert-manager:

```bash
export CLOUDFLARE_API_TOKEN='...'
make cert-manager-cloudflare-secret
```

Check status with:

```bash
make cert-manager-status
```

## Cilium Network Policy

cert-manager has separate workload-scoped Cilium policies:

- `cert-manager-controller` can receive node-origin health probes on `9403`.
- `cert-manager-controller` can reach CoreDNS, the Kubernetes API on `443` and
  Talos control-plane port `6443`, Cloudflare API on `443`, Let's Encrypt ACME
  APIs on `443`, and the configured recursive DNS resolvers `1.1.1.1` and
  `8.8.8.8` on port `53`.
- `cert-manager-webhook` accepts Kubernetes API admission traffic on `10250`
  and node-origin health probes on `6080`.
- `cert-manager-webhook` and `cert-manager-cainjector` can reach CoreDNS and
  the Kubernetes API only.

The Cloudflare and Let's Encrypt egress is intentionally limited to the
controller pod because that is the only component that needs to solve ACME
challenges.
