# RBAC

This application configures Kubernetes RBAC permissions for users authenticated through OIDC.

## Purpose

This application defines authorization rules for users after successful authentication through the Kubernetes OIDC provider.

Authentication and authorization are separate processes:

```text
Authentication
      |
      v
Dex (OIDC Provider)
      |
      v
Kubernetes API Server
      |
      v
RBAC Authorization
```

Dex verifies user identity, while Kubernetes RBAC controls access to cluster resources.

---

## What this application does

- Creates Kubernetes `ClusterRoleBinding`
- Maps OIDC authenticated users to Kubernetes roles
- Grants required permissions based on assigned roles

Current configuration grants administrator access for the configured user.

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
Kubernetes Resources
      |
      v
RBAC Configuration
```

---

## RBAC Configuration

Current configuration:

```yaml
kind: ClusterRoleBinding

subjects:
  - kind: User
    name: emter80@gmail.com

roleRef:
  kind: ClusterRole
  name: cluster-admin
```

The authenticated OIDC user:

```text
emter80@gmail.com
```

is mapped to:

```text
cluster-admin
```

permissions.

---

## Access Model

```text
User
 |
 | Login
 v
Dex OIDC Provider
 |
 | OIDC Token
 v
Kubernetes API Server
 |
 | User identity
 v
ClusterRoleBinding
 |
 v
ClusterRole
 |
 v
Permissions
```

---

## Files

| File | Description |
|------|-------------|
| `app.yaml` | Argo CD Application definition |
| `clusterRoleBinding.yaml` | Maps OIDC user to Kubernetes role |
| `kustomization.yaml` | Kustomize resource definition |

---

## Result

After deployment:

- OIDC authenticated users can access Kubernetes resources.
- Kubernetes API Server recognizes users from Dex.
- RBAC controls permissions based on assigned roles.
- Access management is stored and version-controlled in Git.

---

## Security Considerations

The current configuration grants:

```text
cluster-admin
```

permissions.

This is suitable for a local Kubernetes lab environment.

For production environments, use more restrictive RBAC policies:

- namespace-scoped Roles
- limited ClusterRoles
- group-based access management
- least privilege permissions

---

## Future Improvement

Instead of binding permissions directly to a user:

```yaml
kind: User
name: emter80@gmail.com
```

RBAC can be based on OIDC groups:

```yaml
kind: Group
name: kubernetes-admins
```

with the OIDC claim:

```yaml
oidc-groups-claim=groups
```

This allows centralized user management through Dex and external identity providers.

---

## Dependencies

```text
Dex
 |
 v
OIDC Authentication
 |
 v
Kubernetes API Server
 |
 v
RBAC
 |
 v
ClusterRoleBinding
```
