# Sealed Secrets

This application deploys the **Bitnami Sealed Secrets Controller** used for secure secret management in the Kubernetes cluster.

## Purpose

Kubernetes Secrets are normally stored as plain YAML manifests encoded with base64, which is not suitable for storing sensitive data in Git repositories.

Sealed Secrets provides a GitOps-friendly approach by allowing encrypted secrets to be safely committed to source control.

The workflow:

```text
Plain Secret
     |
     v
kubeseal
     |
     v
SealedSecret (encrypted)
     |
     v
Git Repository
     |
     v
Argo CD
     |
     v
Sealed Secrets Controller
     |
     v
Kubernetes Secret
```

---

## What this application does

- Installs the Sealed Secrets Controller using Helm
- Creates the `sealed-secrets` namespace
- Provides the `kubeseal` encryption/decryption mechanism
- Allows encrypted secrets to be managed through GitOps

The controller watches for:

```yaml
kind: SealedSecret
apiVersion: bitnami.com/v1alpha1
```

and creates regular Kubernetes Secrets inside the cluster.

---

## Deployment Method

The application is managed by Argo CD using the ApplicationSet GitOps workflow.

The application definition:

```text
app.yaml
```

is automatically discovered from:

```text
multipass/k3s/03-apps/**/app.yaml
```

Deployment flow:

```text
Git Repository
      |
      v
Argo CD ApplicationSet
      |
      v
Helm Release
      |
      v
Sealed Secrets Controller
      |
      v
Kubernetes Secrets
```

---

## Helm Chart

Sealed Secrets is deployed using:

| Component | Version |
|----------|---------|
| Helm Chart | sealed-secrets |
| Chart Version | 2.19.1 |

Repository:

```text
https://bitnami.github.io/sealed-secrets
```

---

## Configuration

The Helm chart is configured with:

```yaml
fullnameOverride: sealed-secrets-controller
```

This ensures a predictable controller name:

```text
sealed-secrets-controller
```

The controller is referenced by `kubeseal`:

```bash
kubeseal \
  --controller-name sealed-secrets-controller \
  --controller-namespace sealed-secrets
```

---

## Usage

Generate an encrypted secret:

```bash
kubeseal \
  --controller-name sealed-secrets-controller \
  --controller-namespace sealed-secrets \
  < secret.yaml \
  > sealed-secret.yaml
```

The generated file:

```text
sealed-secret.yaml
```

can safely be committed to Git.

The original Kubernetes Secret should never be stored in the repository.

---

## Managed Secrets

Examples of secrets managed through Sealed Secrets:

```text
03-apps/
├── dex/
│   └── sealed-dex-secret.yaml
│
├── headlamp/
│   └── sealed-headlamp-secret.yaml
```

These encrypted resources are automatically decrypted after deployment.

---

## Files

| File | Description |
|------|-------------|
| `app.yaml` | Argo CD Application definition |
| `values.yaml` | Helm chart configuration |

---

## Result

After deployment:

- Sealed Secrets Controller runs inside the cluster.
- Sensitive configuration can be stored encrypted in Git.
- Argo CD can safely deploy applications containing `SealedSecret` resources.
- Kubernetes Secrets are created automatically at runtime.

---

## Dependencies

```text
Argo CD
 |
 v
Sealed Secrets Controller
 |
 v
SealedSecret Resources
 |
 v
Kubernetes Secrets
 |
 v
Applications
```

Applications using this component:

```text
Dex
 |
 v
dex-config Secret

Headlamp
 |
 v
headlamp-oidc Secret
```

---

## Security Considerations

Sealed Secrets provides encryption for GitOps workflows, but access to the controller private key allows decrypting stored secrets.

Protect:

- Kubernetes API access
- sealed-secrets controller private key
- cluster administrator permissions

For production environments, consider:

- external secret managers
- key rotation procedures
- restricted RBAC permissions
