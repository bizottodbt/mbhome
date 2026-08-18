# Forgejo GitOps Sources

This directory lets Flux sync extra app manifests from the in-cluster Forgejo
instance during the `apps` phase.

The default source is suspended on purpose:

```text
GitRepository:  flux-system/forgejo-apps
Kustomization:  flux-system/forgejo-apps
Repository:     ssh://git@git.apps.mbhome.biz:2222/denis/mbhome-apps.git
Path:           ./clusters/mbhome
Branch:         main
```

Keep the core `mbhome` platform repo in GitHub or another external system. This
Forgejo source is for custom apps and experiments after the cluster, Forgejo,
and Flux are already healthy.

## Authentication model

Flux does not use a Forgejo OAuth app or browser login for Git pulls. The closest
least-privilege equivalent to GitHub App style access is a per-repository
read-only SSH deploy key.

The deploy key lives only as a Kubernetes Secret in `flux-system`:

```text
flux-system/forgejo-apps-deploy-key
```

That Secret is generated with Flux's own `create secret git` helper, so it uses
the key names that source-controller expects.

## Enable the source

Create the Forgejo repository:

```text
denis/mbhome-apps
```

Inside that repo, create a kustomize entry point:

```text
clusters/mbhome/kustomization.yaml
```

Example:

```yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../apps/my-app
```

Generate the Flux deploy key:

```bash
make forgejo-gitops-deploy-key
```

Add the printed public key in Forgejo:

```text
Repository -> Settings -> Deploy Keys -> Add Deploy Key
```

Use read-only access unless Flux needs to push back to the repo.

Then enable the source by setting `suspend: false` in both files:

```text
kubernetes/apps/forgejo-gitops/gitrepository.yaml
kubernetes/apps/forgejo-gitops/kustomization-forgejo-apps.yaml
```

Commit, push, and reconcile:

```bash
make flux-reconcile
make forgejo-gitops-status
```

## Custom repo name

If you choose a different Forgejo repo, update the `url` in:

```text
kubernetes/apps/forgejo-gitops/gitrepository.yaml
```

Then run the deploy-key target with matching variables:

```bash
make forgejo-gitops-deploy-key \
  FORGEJO_GITOPS_REPO_OWNER=denis \
  FORGEJO_GITOPS_REPO_NAME=my-private-apps
```
