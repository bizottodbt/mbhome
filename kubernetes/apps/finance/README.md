# Finance Forgejo Source

This directory is the Flux connector for the Forgejo repository:

```text
ssh://git@git.apps.mbhome.biz:2222/denis/finance.git
```

It owns:

```text
Namespace:       finance
GitRepository:  flux-system/finance
Kustomization:  flux-system/finance
Deploy key:     flux-system/finance-deploy-key
```

The actual app manifests should live in the Forgejo repo under:

```text
kubernetes/
```

The source is suspended by default. Enable it only after:

1. The `denis/finance` Forgejo repo exists.
2. `make forgejo-gitops-deploy-key FORGEJO_GITOPS_APP=finance` has created the deploy key Secret.
3. The printed public key has been added as a read-only deploy key in Forgejo.
4. The Forgejo repo contains `kubernetes/kustomization.yaml`.

Then set `suspend: false` in:

```text
gitrepository.yaml
flux-kustomization.yaml
```
