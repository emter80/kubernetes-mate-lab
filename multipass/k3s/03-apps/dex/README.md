# Dex

This application deploys **Dex** as an OpenID Connect (OIDC) identity provider for the Kubernetes cluster.

## Purpose

Dex provides authentication for Kubernetes and cluster applications by acting as an OIDC bridge between external identity providers and Kubernetes.

In this lab, Dex is used as the central authentication service for:

- Kubernetes API Server OIDC authentication
- Headlamp SSO
- Other Kubernetes tools requiring OIDC authentication

Dex delegates user authentication to external identity providers (for example GitHub OAuth) and issues OIDC tokens consumed by Kubernetes clients.

## Architecture

```text
User
 |
 | Login
 v
GitHub OAuth Provider
 |
 v
Dex (OIDC Provider)
 |
 | OIDC Token
 v
Kubernetes API Server / Applications
 |
 v
Kubernetes RBAC
```

## What this application does

- Installs Dex using the official Helm chart
- Creates a dedicated `dex` namespace
- Configures Dex using a Sealed Secret
- Creates a TLS certificate using cert-manager
- Exposes Dex through Traefik HTTPS IngressRoute
- Provides an internal OIDC endpoint:

```text
https://dex.multipass.k3s
```

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

## Components

### Helm Chart

Dex is deployed using:

| Component | Version |
|----------|---------|
| Helm Chart | dex |
| Chart Version | 0.24.1 |

Repository:

```text
https://charts.dexidp.io
```

---

## TLS Certificate

The application creates a certificate using cert-manager:

```yaml
kind: Certificate
name: dex-tls
namespace: dex
```

Certificate details:

```text
DNS Name:
dex.multipass.k3s

Issuer:
multipass-ca
```

The certificate is stored in:

```text
Secret:
dex-tls
```

The certificate is issued by the internal cluster Certificate Authority.

---

## Ingress

Dex is exposed through Traefik using an `IngressRoute`.

Configuration:

```text
Hostname:
dex.multipass.k3s

EntryPoint:
websecure

Service:
dex:5556
```

Traffic flow:

```text
Client
 |
HTTPS
 |
 v
Traefik
 |
 v
Dex Service
 |
 v
Dex Pod
```

---

## Secrets Management

Dex configuration is stored as a Kubernetes Sealed Secret:

```text
sealed-dex-secret.yaml
```

The encrypted secret contains:

```text
config.yaml
```

The secret is decrypted inside the cluster by the Sealed Secrets controller.

Flow:

```text
Encrypted Secret
        |
        v
Sealed Secrets Controller
        |
        v
Kubernetes Secret
        |
        v
Dex
```

Plain Dex configuration is never stored in Git.

---

## Resource Configuration

Dex resource limits:

| Resource | Request | Limit |
|----------|---------|-------|
| CPU | 50m | 200m |
| Memory | 64Mi | 256Mi |

Service type:

```text
ClusterIP
```

External access is provided through Traefik.

---

## Files

| File | Description |
|------|-------------|
| `app.yaml` | Argo CD ApplicationSet definition |
| `values.yaml` | Helm chart configuration |
| `certificate.yaml` | cert-manager TLS certificate definition |
| `ingressroute.yaml` | Traefik HTTPS route |
| `sealed-dex-secret.yaml` | Encrypted Dex configuration |
| `kustomization.yaml` | Kustomize resource definition |

---

## Result

After deployment:

- Dex is running inside the `dex` namespace.
- HTTPS access is available at:

```text
https://dex.multipass.k3s
```

- Kubernetes API Server can authenticate users using Dex OIDC.
- Applications can use Dex as a centralized authentication provider.

## Related Components

This application depends on:

- cert-manager
- multipass-ca ClusterIssuer
- Traefik Ingress Controller
- Sealed Secrets Controller
- Argo CD GitOps workflow
- Kubernetes OIDC configuration
