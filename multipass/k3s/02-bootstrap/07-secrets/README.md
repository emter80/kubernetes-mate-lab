# Secrets

This module automates the management of Kubernetes secrets using **Bitnami Sealed Secrets**.

## Purpose

The module converts plain Kubernetes `Secret` manifests into encrypted `SealedSecret` resources that are safe to store in Git. Whenever a secret changes, Terraform automatically regenerates the corresponding Sealed Secret, commits the changes, and pushes them to the repository.

## What this module does

- Discovers plain Secret manifests in the `topsecret` directory
- Encrypts each Secret using `kubeseal`
- Generates a corresponding `SealedSecret` for each application
- Stores generated manifests under `03-apps/<application>/`
- Automatically commits and pushes updated Sealed Secrets to Git
- Regenerates Sealed Secrets only when the source Secret changes

## Directory Structure

### Input

```text
topsecret/
├── plain-argocd-secret.yaml
├── plain-dex-secret.yaml
└── ...
```

### Output

```text
03-apps/
├── argocd/
│   └── sealed-argocd-secret.yaml
├── dex/
│   └── sealed-dex-secret.yaml
└── ...
```

## Workflow

```text
Plain Secret
      │
      ▼
kubeseal
      │
      ▼
SealedSecret
      │
      ▼
Git Commit
      │
      ▼
Git Push
      │
      ▼
Argo CD
      │
      ▼
Kubernetes Secret
```

## Requirements

This module assumes that:

- Sealed Secrets is already installed in the cluster
- `kubeseal` is installed locally
- Git is installed and configured
- The local repository has permission to push to the remote repository

## Terraform Resources

| Resource | Description |
|----------|-------------|
| `terraform_data.seal_secret` | Generates Sealed Secrets using `kubeseal` |
| `terraform_data.git_commit_sealed_secrets` | Commits and pushes updated Sealed Secrets |

## Files

| File | Description |
|------|-------------|
| `main.tf` | Discovers, seals, commits, and pushes Kubernetes secrets |

## Usage

```bash
terraform init
terraform apply
```

## Outputs

The module provides information about:

- Source-to-target secret mapping
- Generated Sealed Secret files
- Git commit status

## Result

After this module completes:

- Plain secrets remain outside the GitOps application directories.
- Encrypted `SealedSecret` manifests are stored in the Git repository.
- Updated secrets are automatically committed and pushed.
- Argo CD detects the Git changes and synchronizes the updated secrets to the cluster.

## Security

Only encrypted `SealedSecret` manifests are stored in the Git repository. Plain Secret manifests remain in the local `topsecret` directory and should never be committed to source control.
