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

Create a runner connection in Forgejo:

```text
Site Administration -> Actions -> Runners -> Create new runner
```

Forgejo displays a `uuid` and confidential `token`. Store both in Vault:

```bash
export FORGEJO_RUNNER_UUID='...'
export FORGEJO_RUNNER_TOKEN='...'
make forgejo-runner-registration-secret
```

The connection values are stored at:

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

Each label currently runs jobs in `ghcr.io/catthehacker/ubuntu:act-22.04`.
That image is heavier than plain `node`, but it includes the common tools needed
by GitHub-compatible workflows, including Node.js, Git, and the Docker CLI.
Docker commands talk to the isolated Docker-in-Docker sidecar through
`DOCKER_HOST=unix:///var/run/docker/docker.sock`.

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
      - run: docker version
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
