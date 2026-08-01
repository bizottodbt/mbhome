# ImmichFrame

ImmichFrame is exposed through the internal Gateway:

```text
https://immichframe.apps.mbhome.biz
```

The app reads non-secret settings from `Settings.yml`, which Kustomize turns
into the `immichframe-config` ConfigMap. The Immich API key and optional weather
API key are synced from Vault by Vault Secrets Operator.

Seed the Vault secret before reconciling the app:

```bash
kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome \
  -n vault exec -it vault-0 -- vault login

kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome \
  -n vault exec vault-0 -- \
  vault kv put mbhome/apps/immichframe \
    immich-api-key='<immich-api-key>' \
    weather-api-key='<openweathermap-api-key>'
```

If the Immich key already exists and you only want to add or rotate the weather
key, patch the existing Vault secret instead of replacing it:

```bash
kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome \
  -n vault exec vault-0 -- \
  vault kv patch mbhome/apps/immichframe weather-api-key='<openweathermap-api-key>'
```

The keys in Vault are mounted into the pod at:

```text
/app/secrets/immich-api-key
/app/secrets/weather-api-key
```

ImmichFrame needs an Immich API key with read-only photo/library permissions.
Weather uses OpenWeatherMap. The location is configured in `Settings.yml` with
`WeatherLatLong`, and temperature units follow `UnitSystem`.

Validate after Flux reconciles:

```bash
kubectl --kubeconfig infrastructure/talos/clusters/mbhome/kubeconfig \
  --context admin@mbhome \
  -n immichframe get deploy,svc,httproute,vaultstaticsecret,secret

curl -Ik https://immichframe.apps.mbhome.biz
```
