# 03 - Argo CD

This module installs **Argo CD** into the K3s cluster using the Terraform Helm provider.

## Purpose

Argo CD is a GitOps continuous delivery tool for Kubernetes. It continuously monitors Git repositories and synchronizes the desired application state with the cluster.

In this lab, Argo CD is responsible for deploying and managing all Kubernetes applications from the Git repository.

## What this module does

- Installs Argo CD using the official Helm chart
- Creates the `argocd` namespace
- Configures the Argo CD server to run with the `--insecure` flag
- Prepares the cluster for GitOps-based application deployment

## Terraform Provider

The module uses the Terraform Helm provider configured to access the K3s cluster through the local kubeconfig.

```text
~/.kube/config.multipass.k3s
```

## Installed Version

| Component | Version |
|----------|---------|
| Argo CD | 10.2.1 |
| Helm Provider | 3.2.0 |

## Configuration

The Argo CD server is started with:

```text
--insecure
```

TLS termination is handled externally by Traefik using certificates issued by cert-manager.

## Files

| File | Description |
|------|-------------|
| `providers.tf` | Configures the Helm provider and Kubernetes connection |
| `argocd.tf` | Installs Argo CD using the official Helm chart |

## Usage

```bash
terraform init
terraform apply
```

## Result

After this module completes, Argo CD is installed and ready to manage Kubernetes applications using the GitOps workflow.

## Next Step

Continue with the next bootstrap module to configure ingress, repositories, authentication, and deploy applications managed by Argo CD.
