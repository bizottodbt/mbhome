# Apps

Flux reconciles this directory after the infrastructure layer is ready.

The initial `whoami` app is a small Gateway API smoke test exposed only through
the internal Gateway:

```text
http://whoami.apps.mbhome.biz
https://whoami.apps.mbhome.biz
```

Validate after Flux reconciles:

```bash
kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  -n whoami get deploy,svc,httproute

curl -i http://whoami.apps.mbhome.biz
curl -Ik https://whoami.apps.mbhome.biz
```
