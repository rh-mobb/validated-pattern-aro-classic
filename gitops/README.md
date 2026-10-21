# In-cluster GitOps

OLM Classic `Subscription`s + Kustomize. Install OpenShift GitOps, then Argo CD syncs this directory.

```bash
make cluster.<profile>.kubeconfig
make cluster.<profile>.apply   # Key Vault redhat-pull-secret when pull_secret_path is set
make cluster.<profile>.bootstrap
```

Guide: [GitOps bootstrap](../docs/guides/gitops.md). Example overlay: `gitops/overlays/aro-classic-miwi`. Argo CD UI uses **OpenShift OAuth** (not HCP Entra `external-auth`).
