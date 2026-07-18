# Dex Postgres

Dex uses this dedicated PostgreSQL database for OAuth state, refresh tokens,
replay prevention data, and signing keys.

Create the application credential secret before Flux reconciles this layer:

```bash
export DEX_POSTGRES_PASSWORD='...'
make dex-postgres-secret
```

The `dex-postgres-app` secret uses Kubernetes `basic-auth` keys because
CloudNativePG expects `username` and `password` for the application owner.
