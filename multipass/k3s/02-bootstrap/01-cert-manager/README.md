# 01 - cert-manager

This module installs **cert-manager** into the K3s cluster using the Terraform Helm provider.

## Purpose

cert-manager automates the management and lifecycle of TLS certificates in Kubernetes. It provides the foundation for issuing and renewing certificates that are later used by applications such as Argo CD, Headlamp, and Dex.

## What this module does

- Installs cert-manager using the official Jetstack Helm chart
- Creates the `cert-manager` namespace
- Installs the required Custom Resource Definitions (CRDs)
- Waits until the installation is complete before Terraform finishes

## Terraform Provider

The module uses the Terraform Helm provider configured to access the K3s cluster through the local kubeconfig.

```text
~/.kube/config.multipass.k3s
```

## Installed Version

Component - Version
- cert-manager - v1.21.0
- Helm Provider - 3.2.0

## Files

File - Description
- `providers.tf` - Configures the Helm provider and Kubernetes connection
- `cert-manager.tf` - Installs cert-manager using the official Helm chart

## Usage

```bash
terraform init
terraform apply
```

## Next Step

After cert-manager has been installed, continue with the next bootstrap module to configure certificate issuers and cluster certificates.
