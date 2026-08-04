# Headlamp

This application deploys **Headlamp** as a Kubernetes web-based user interface with OIDC authentication enabled through Dex.

## Purpose

Headlamp provides a graphical interface for managing and monitoring Kubernetes resources.

In this lab, Headlamp is integrated with the cluster identity platform:

- Dex provides OIDC authentication
- Kubernetes API Server validates OIDC tokens
- Kubernetes RBAC controls user permissions

This provides a complete SSO experience for Kubernetes users.

## Architecture

```text
User
 |
 | HTTPS
 v
Traefik
 |
 v
Headlamp
 |
 | OIDC Login
 v
Dex
 |
 | Token
 v
Kubernetes API Server
 |
 v
Kubernetes RBAC
```

## What this application does

- Installs Headlamp using the official Helm chart
- Creates a dedicated `headlamp` namespace
- Configures OIDC authentication
- Creates a TLS certificate using cert-manager
- Exposes Headlamp through Traefik HTTPS IngressRoute
- Mounts the internal CA certificate for trusted HTTPS communication

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

---

## Helm Chart

Headlamp is deployed using:

| Component | Version |
|----------|---------|
| Helm Chart | headlamp |
| Chart Version | 0.43.0 |

Repository:

```text
https://kubernetes-sigs.github.io/headlamp/
```

---

## TLS Certificate

The application creates a TLS certificate using cert-manager:

```yaml
kind: Certificate
name: headlamp-tls
namespace: headlamp
```

Certificate details:

```text
DNS Name:
headlamp.multipass.k3s

Issuer:
multipass-ca
```

The generated certificate is stored in:

```text
Secret:
headlamp-tls
```

---

## Ingress

Headlamp is exposed using a Traefik `IngressRoute`.

Configuration:

```text
Hostname:
headlamp.multipass.k3s

EntryPoint:
websecure

Service:
headlamp:80
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
Headlamp Service
 |
 v
Headlamp Pod
```

---

## OIDC Authentication

Headlamp uses Dex as the OIDC identity provider.

OIDC configuration:

| Parameter | Value |
|----------|-------|
| Issuer URL | `https://dex.multipass.k3s` |
| Callback URL | `https://headlamp.multipass.k3s/oidc-callback` |
| Client ID | `headlamp` |
| Scopes | Configured through Secret |

The OIDC configuration is stored securely in:

```text
Secret:
headlamp-oidc
```

The secret is delivered using Bitnami Sealed Secrets.

Flow:

```text
SealedSecret
      |
      v
Sealed Secrets Controller
      |
      v
Kubernetes Secret
      |
      v
Headlamp
```

---

## Internal CA Trust

Headlamp communicates with internal HTTPS services secured by certificates issued by `multipass-ca`.

The cluster CA certificate is provided through:

```text
ConfigMap:
multipass-root-ca
```

and mounted into the container:

```text
/etc/ssl/certs/multipass-root-ca.crt
```

This allows Headlamp to trust:

```text
https://dex.multipass.k3s
```

and other internal TLS endpoints.

---

## Resource Configuration

The application uses the default Helm chart resources.

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
| `sealed-headlamp-secret.yaml` | Encrypted OIDC configuration |
| `kustomization.yaml` | Kustomize resource definition |

---

## Result

After deployment:

- Headlamp is available at:

```text
https://headlamp.multipass.k3s
```

- Users authenticate through Dex.
- Kubernetes RBAC determines accessible resources.
- Internal TLS certificates are trusted automatically.

## Dependencies

Headlamp requires:

```text
Argo CD
 |
 v
Headlamp

cert-manager
 |
 v
multipass-ca

Traefik
 |
 v
IngressRoute

Dex
 |
 v
OIDC Authentication

Sealed Secrets
 |
 v
headlamp-oidc Secret

trust-manager
 |
 v
multipass-root-ca ConfigMap
```
