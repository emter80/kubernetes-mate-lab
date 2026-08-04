# 08 - OIDC

This module configures **K3s Kubernetes API Server OIDC authentication** using Dex as the identity provider.

## Purpose

The module enables Kubernetes authentication through an external OpenID Connect (OIDC) provider.

In this lab, Dex provides user authentication through GitHub OAuth, while the Kubernetes API Server validates OIDC tokens issued by Dex.

This allows users to authenticate to Kubernetes using their external identity instead of local Kubernetes certificates or static credentials.

## Authentication Flow

```text
User
 |
 | Login with GitHub
 v
Dex (OIDC Provider)
 |
 | ID Token
 v
Kubernetes API Server
 |
 | Validate token
 v
Kubernetes RBAC
 |
 v
Access granted
```

## What this module does

- Retrieves the internal root CA certificate from cert-manager
- Stores the CA certificate locally
- Copies the CA certificate to the K3s master node
- Configures K3s API Server OIDC parameters
- Restarts the K3s service to enable OIDC authentication

## OIDC Configuration

The Kubernetes API Server is configured with:

| Parameter | Value |
|-----------|-------|
| OIDC Issuer URL | `https://dex.multipass.k3s` |
| Client ID | `kubernetes` |
| Username Claim | `email` |
| Groups Claim | `groups` |
| CA Certificate | `/etc/rancher/k3s/multipass-root-ca.crt` |

## Why the CA Certificate is Required

Dex uses a TLS certificate issued by the internal `multipass-ca` Certificate Authority.

The Kubernetes API Server must trust this CA in order to validate the HTTPS connection to:

```text
https://dex.multipass.k3s
```

The module installs this trust chain by copying:

```text
multipass-root-ca.crt
```

to:

```text
/etc/rancher/k3s/multipass-root-ca.crt
```

## Terraform Providers

The module uses:

- Kubernetes provider - reads the CA Secret from the cluster
- Local provider - creates the CA certificate file
- Null provider - executes Multipass and K3s configuration commands

Kubeconfig:

```text
~/.kube/config.multipass.k3s
```

## Resources

| Resource | Description |
|----------|-------------|
| `kubernetes_secret_v1` | Reads the root CA Secret created by cert-manager |
| `local_file` | Creates local CA certificate file |
| `null_resource.k3s_oidc` | Transfers files and updates K3s configuration |

## Files

| File | Description |
|------|-------------|
| `providers.tf` | Configures Terraform providers |
| `config.yaml` | Defines K3s OIDC API Server arguments |
| `main.tf` | Automates CA extraction and K3s configuration |
| `multipass-root-ca.crt` | Root CA certificate trusted by K3s API Server |

## Usage

```bash
terraform init
terraform apply
```

## Result

After this module completes:

- Kubernetes API Server accepts OIDC tokens from Dex.
- Users can authenticate using their external identity provider.
- Kubernetes RBAC can be configured using OIDC usernames and groups.

Example:

```bash
kubectl login through OIDC provider
```

or tools such as:

- Headlamp
- kubectl OIDC plugins
- Other Kubernetes dashboards

can authenticate through Dex.

## Security Considerations

- The Kubernetes API Server trusts only the configured internal CA.
- User permissions are controlled by Kubernetes RBAC.
- OIDC authentication provides identity verification, but authorization remains managed by Kubernetes roles and bindings.

## Next Step

Configure RBAC bindings for OIDC users and groups to control access to Kubernetes resources.
