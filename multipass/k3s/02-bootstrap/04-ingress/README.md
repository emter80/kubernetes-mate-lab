# 04 - Ingress

This module exposes the Argo CD web interface through Traefik and secures it with a TLS certificate issued by the cluster's private Certificate Authority.

## Purpose

The module creates a TLS certificate for Argo CD and configures a Traefik `IngressRoute` to provide secure HTTPS access to the Argo CD server.

## What this module does

- Creates a TLS certificate for `argocd.multipass.k3s`
- Uses the `multipass-ca` ClusterIssuer to sign the certificate
- Stores the certificate in the `argocd-tls` Secret
- Creates a Traefik `IngressRoute`
- Exposes the Argo CD server over HTTPS

## Architecture

```text
Client
   │
HTTPS
   │
   ▼
Traefik
   │
IngressRoute
   │
   ▼
argocd-server Service
   │
   ▼
Argo CD
```

## Terraform Provider

The module uses the Terraform Kubernetes provider configured to access the K3s cluster through the local kubeconfig.

```text
~/.kube/config.multipass.k3s
```

## Resources Created

| Resource | Description |
|----------|-------------|
| `Certificate/argocd-tls` | TLS certificate for `argocd.multipass.k3s` |
| `Secret/argocd-tls` | Stores the generated certificate and private key |
| `IngressRoute/argocd` | Traefik route exposing the Argo CD web interface |

## Files

| File | Description |
|------|-------------|
| `providers.tf` | Configures the Kubernetes provider |
| `argocd-cert.tf` | Creates the TLS certificate for Argo CD |
| `argocd-ingress.tf` | Creates the Traefik IngressRoute |

## Usage

```bash
terraform init
terraform apply
```

## Result

After this module completes, the Argo CD web interface is available at:

```text
https://argocd.multipass.k3s
```

The connection is secured using a certificate issued by the cluster's private Certificate Authority (`multipass-ca`).

## Next Step

Continue with the next bootstrap module to configure GitOps repositories, applications, or authentication for Argo CD.
