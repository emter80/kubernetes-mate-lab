# 02 - Certificates

This module configures the certificate infrastructure for the K3s cluster using cert-manager.

## Purpose

The module creates a private Certificate Authority (CA) that is used to issue TLS certificates for services running inside the cluster. It also configures the required RBAC permissions for cert-manager components.

## What this module does

- Creates a self-signed `ClusterIssuer`
- Generates a root CA certificate (`multipass-root-ca`)
- Stores the root CA private key and certificate in a Kubernetes Secret
- Creates a CA-based `ClusterIssuer` (`multipass-ca`) that signs application certificates
- Grants the `cert-manager-cainjector` ServiceAccount permission to update ConfigMaps

## Certificate Hierarchy

```text
SelfSigned ClusterIssuer
        │
        ▼
multipass-root-ca (CA Certificate)
        │
        ▼
multipass-ca (CA ClusterIssuer)
        │
        ▼
Application TLS Certificates
```

## Terraform Provider

The module uses the Terraform Kubernetes provider configured to access the K3s cluster through the local kubeconfig.

```text
~/.kube/config.multipass.k3s
```

## Installed Components

| Resource | Description |
|----------|-------------|
| `ClusterIssuer/selfsigned` | Temporary self-signed issuer used to bootstrap the root CA |
| `Certificate/multipass-root-ca` | Root Certificate Authority |
| `ClusterIssuer/multipass-ca` | CA issuer used to sign application certificates |
| `ClusterRole` | Allows cert-manager-cainjector to update ConfigMaps |
| `ClusterRoleBinding` | Assigns the ClusterRole to the cert-manager-cainjector ServiceAccount |

## Files

| File | Description |
|------|-------------|
| `providers.tf` | Configures the Kubernetes provider |
| `cluster-issuer.tf` | Creates the self-signed and CA ClusterIssuers |
| `ca.tf` | Generates the root CA certificate |
| `rbac.tf` | Grants additional permissions to cert-manager-cainjector |

## Usage

```bash
terraform init
terraform apply
```

## Result

After this module completes, the cluster contains a private Certificate Authority that can issue trusted TLS certificates for applications such as Traefik, Argo CD, Headlamp, and Dex.

## Next Step

Continue with the next bootstrap module to install and configure cluster applications that will use the `multipass-ca` ClusterIssuer.
