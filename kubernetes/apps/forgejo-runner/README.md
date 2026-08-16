# Forgejo Runner

Forgejo Runner executes Forgejo Actions jobs for the internal Forgejo instance.
The runner is deployed in its own Pod Security `privileged` namespace because
it uses an isolated Docker-in-Docker sidecar for workflow containers.

```text
Forgejo server: https://git.apps.mbhome.biz
Runner namespace: forgejo-runner
```

## Bootstrap

Enable the namespace Vault role once:

```bash
make vault-app-namespace-bootstrap VAULT_APP_NAMESPACE=forgejo-runner
```

Create a runner registration token in Forgejo:

```text
Site Administration -> Actions -> Runners -> Create new runner
```

Store the registration token in Vault:

```bash
export FORGEJO_RUNNER_REGISTRATION_TOKEN='...'
make forgejo-runner-registration-secret
```

The token is stored at:

```text
mbhome/apps/forgejo-runner/registration
```

Vault Secrets Operator syncs it to:

```text
forgejo-runner/forgejo-runner-registration
```

Then commit, push, reconcile, and check status:

```bash
make flux-reconcile
make forgejo-runner-status
```

## Workflow Labels

The first runner exposes these labels:

```text
docker
ubuntu-latest
self-hosted
```

Each label currently runs jobs in `docker.io/library/node:22-bookworm`. This is
good enough for simple private-repo CI and common JavaScript-based actions. For
heavier GitHub-compatible workflows, replace or add a label that points at a
larger runner image.

Example workflow:

```yaml
---
on: [push]
jobs:
  smoke:
    runs-on: docker
    steps:
      - uses: actions/checkout@v6
      - run: node --version
      - run: git --version
```

## Security Notes

Forgejo Actions execute repository code. Treat runner access as remote code
execution:

- keep this runner for trusted private repositories first
- do not mount a Kubernetes service account token into the runner
- do not mount the host Docker socket
- keep Docker-in-Docker isolated in this namespace
- add more runner namespaces later if different trust levels are needed
