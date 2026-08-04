# Whoami

This application deploys a simple HTTP echo service used for Kubernetes ingress, networking, and TLS validation.

## Purpose

`whoami` is a lightweight test application provided by Traefik that displays information about the incoming HTTP request.

It is used in this Kubernetes lab to verify:

- Kubernetes deployment
- Service discovery
- Traefik IngressRoute configuration
- TLS certificate management
- Internal Certificate Authority trust chain

---

## Architecture

```text
User
 |
 | HTTPS
 v
Traefik Ingress Controller
 |
 | TLS termination
 v
IngressRoute
 |
 v
Service
 |
 v
Whoami Pod
```

---

## What this application does

- Creates a dedicated `whoami` namespace
- Deploys the Traefik `whoami` container
- Exposes the application through Kubernetes Service
- Creates an HTTPS endpoint using Traefik
- Generates TLS certificates using cert-manager

Application URL:

```text
https://whoami.multipass.k3s
```

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
Kustomize
      |
      v
Kubernetes Resources
      |
      v
Whoami Application
```

---

## Container

The application uses:

```text
Image:
traefik/whoami:v1.11.0
```

The container listens on:

```text
Port:
80
```

---

## Kubernetes Resources

### Deployment

The application runs:

```yaml
replicas: 1
```

Container resources:

| Resource | Request | Limit |
|----------|---------|-------|
| CPU | 10m | 50m |
| Memory | 16Mi | 32Mi |

---

### Service

The application is exposed internally through:

```text
Service:
whoami

Port:
80
```

Traffic flow:

```text
IngressRoute
      |
      v
Service
      |
      v
Pod:80
```

---

## TLS Certificate

The application uses cert-manager to generate a TLS certificate.

Certificate:

```yaml
kind: Certificate
name: whoami-cert
namespace: whoami
```

Certificate details:

```text
DNS Name:
whoami.multipass.k3s

Issuer:
multipass-ca
```

The generated certificate is stored in:

```text
Secret:
whoami-tls
```

---

## Ingress Configuration

Traffic is exposed using Traefik `IngressRoute`.

Configuration:

```text
Hostname:
whoami.multipass.k3s

EntryPoint:
websecure

Service:
whoami:80
```

Request flow:

```text
Client
 |
HTTPS
 |
 v
Traefik
 |
TLS Certificate:
whoami-tls
 |
 v
whoami Service
 |
 v
whoami Pod
```

---

## Files

| File | Description |
|------|-------------|
| `app.yaml` | Argo CD Application definition |
| `deployment.yaml` | Kubernetes Deployment |
| `service.yaml` | Kubernetes Service |
| `certificate.yaml` | cert-manager TLS certificate |
| `ingressroute.yaml` | Traefik HTTPS route |
| `kustomization.yaml` | Kustomize resource definition |

---

## Result

After deployment:

- The application is available at:

```text
https://whoami.multipass.k3s
```

- HTTPS is provided by Traefik.
- Certificates are issued automatically by cert-manager.
- The application can be used to validate ingress and networking configuration.

Example response:

```text
Hostname: whoami-xxxxx
IP: 10.x.x.x
Method: GET
URL: /
```

---

## Dependencies

```text
Argo CD
 |
 v
ApplicationSet

cert-manager
 |
 v
multipass-ca ClusterIssuer
 |
 v
whoami-tls Certificate

Traefik
 |
 v
IngressRoute
 |
 v
whoami Service
 |
 v
whoami Pod
```
