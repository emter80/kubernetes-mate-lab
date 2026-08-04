# 05 - GitOps

This module configures **Argo CD ApplicationSet** to automatically discover and deploy applications from the Git repository.

## Purpose

The module enables a GitOps workflow where applications are managed declaratively in Git. Argo CD automatically detects application definitions, creates corresponding `Application` resources, and keeps the cluster synchronized with the repository.

## What this module does

- Creates an `ApplicationSet` named `platform-apps`
- Scans the Git repository for application definitions
- Automatically generates Argo CD `Application` resources
- Supports both Helm and Kustomize applications
- Enables automatic synchronization, pruning, and self-healing
- Automatically creates target namespaces when required

## Repository Structure

The ApplicationSet discovers application definitions located at:

```text
multipass/k3s/03-apps/**/app.yaml
```

Each `app.yaml` file describes a single application to be deployed by Argo CD.

## Supported Application Types

The ApplicationSet supports two deployment methods:

### Helm

Applications can reference an external Helm chart while storing custom values in this repository.

```text
Helm Repository
      │
      ▼
 Helm Chart
      │
      ▼
Custom values (Git)
```

### Kustomize

Applications can also be deployed directly from Kubernetes manifests using Kustomize.

```text
Git Repository
      │
      ▼
Kustomize Directory
      │
      ▼
Kubernetes Resources
```

## Sync Policy

Applications are configured with automated synchronization:

- Automatic sync
- Automatic pruning of removed resources
- Self-healing when drift is detected
- Automatic namespace creation

## Terraform Provider

The module uses the Terraform Kubernetes provider configured to access the K3s cluster through the local kubeconfig.

```text
~/.kube/config.multipass.k3s
```

## Resources Created

| Resource | Description |
|----------|-------------|
| `ApplicationSet/platform-apps` | Automatically generates Argo CD Applications from Git |

## Files

| File | Description |
|------|-------------|
| `providers.tf` | Configures the Kubernetes provider |
| `applicationset.tf` | Creates the GitOps ApplicationSet |

## Usage

```bash
terraform init
terraform apply
```

## Result

After this module completes, Argo CD continuously monitors the Git repository and automatically deploys or updates applications defined under:

```text
multipass/k3s/03-apps/
```

Adding, modifying, or removing an `app.yaml` file in the repository automatically updates the cluster without any manual intervention.

## Next Step

Bootstrap is complete. Additional applications can now be deployed simply by adding new application definitions under the `03-apps` directory.
