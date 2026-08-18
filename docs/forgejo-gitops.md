# Forgejo GitOps Source Pattern

Forgejo-hosted repositories are synced one repo at a time. Each repo gets its
own directory under `kubernetes/apps/`, its own namespace, its own Flux
`GitRepository`, its own Flux `Kustomization`, and its own deploy key.

The platform repo still owns the connector objects. The Forgejo repo owns the
actual app manifests.

```text
mbhome platform repo:
  kubernetes/apps/<repo-name>/
    namespace.yaml
    gitrepository.yaml
    flux-kustomization.yaml
    kustomization.yaml

Forgejo repo:
  kubernetes/
    kustomization.yaml
    deployment.yaml
    service.yaml
    httproute.yaml
```

The core `mbhome` platform repo should remain in GitHub or another external Git
system for recovery. Forgejo-hosted GitOps is for second-wave custom apps after
Forgejo and Flux are already healthy.

Do not create documentation-only directories under `kubernetes/apps/`. That
directory should contain active app units only.

## Current Sources

```text
kubernetes/apps/finance/
```

The `finance` source is suspended until the Forgejo repo and deploy key are
ready.

## Authentication Model

Flux does not use a Forgejo OAuth app or browser login for Git pulls. The
least-privilege equivalent is a per-repository read-only SSH deploy key.

Each source uses a separate Secret in `flux-system`:

```text
flux-system/<repo-name>-deploy-key
```

Generate the deploy key for a source by passing the app name explicitly:

```bash
make forgejo-gitops-deploy-key FORGEJO_GITOPS_APP=<repo-name>
```

Add the printed public key in Forgejo:

```text
Repository -> Settings -> Deploy Keys -> Add Deploy Key
```

Use read-only access unless Flux needs to write back to the repo.

## Enable a Source

Create the Forgejo repository. For the current example:

```text
denis/finance
```

Inside that repo, create:

```text
kubernetes/kustomization.yaml
```

Example:

```yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
  - httproute.yaml
```

Then set `suspend: false` in the platform repo source files:

```text
kubernetes/apps/<repo-name>/gitrepository.yaml
kubernetes/apps/<repo-name>/flux-kustomization.yaml
```

After review, commit and push the platform repo changes, then reconcile:

```bash
make flux-reconcile
make forgejo-gitops-status FORGEJO_GITOPS_APP=<repo-name>
```

## Add Another Forgejo Repo

Copy the `finance` directory:

```bash
cp -R kubernetes/apps/finance kubernetes/apps/<repo-name>
```

Then update:

```text
kubernetes/apps/<repo-name>/namespace.yaml
kubernetes/apps/<repo-name>/gitrepository.yaml
kubernetes/apps/<repo-name>/flux-kustomization.yaml
kubernetes/apps/kustomization.yaml
```

Use the repo name consistently for:

```text
Namespace:       <repo-name>
GitRepository:  <repo-name>
Kustomization:  <repo-name>
Secret:         <repo-name>-deploy-key
Forgejo repo:   ssh://git@git.apps.mbhome.biz:2222/denis/<repo-name>.git
```
