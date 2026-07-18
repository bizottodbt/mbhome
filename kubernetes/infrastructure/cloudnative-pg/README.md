# CloudNativePG

CloudNativePG installs the PostgreSQL operator used by platform components that
need a durable SQL backend.

The operator is installed by Flux before database clusters are reconciled. Keep
database `Cluster` resources in a later Flux layer so their CRDs already exist.
