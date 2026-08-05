# 07 - trust-manager

This module installs and configures **trust-manager** to distribute the internal Kubernetes Certificate Authority across the cluster.

## Purpose

trust-manager is a cert-manager project that manages and distributes CA certificates to Kubernetes workloads.

In this lab, it is used to make the private `multipass-root-ca` certificate available as ConfigMaps, allowing applications and containers to trust certificates issued by the internal CA.

## What this module does

- Installs trust-manager using the official Jetstack Helm chart
- Creates the required trust-manager Custom Resource Definitions (CRDs)
- Waits until the `Bundle` CRD becomes available
- Creates a `Bundle` resource that distributes the internal CA certificate
- Creates ConfigMaps containing the trusted CA certificate

## Certificate Distribution Flow

```text
cert-manager
      |
      v
multipass-root-ca Secret
      |
      v
trust-manager Bundle
      |
      v
ConfigMaps with ca.crt
      |
      v
Applications
      |
      v
Trusted TLS connections
```

## Terraform Providers

This module uses both Helm and Kubernetes providers.

Kubeconfig:

```text
~/.kube/config.multipass.k3s
```

## Installed Version

| Component | Version |
|----------|---------|
| trust-manager | v0.24.0 |
| Helm Provider | 3.2.0 |
| Kubernetes Provider | 3.2.1 |

## Resources Created

| Resource | Description |
|----------|-------------|
| Helm Release `trust-manager` | Installs trust-manager controller |
| Bundle `multipass-root-ca` | Distributes the internal CA certificate |
| ConfigMaps | Store the trusted CA bundle |

## Bundle Configuration

The Bundle resource reads:

```text
Secret:
cert-manager/multipass-root-ca

Key:
ca.crt
```

and creates ConfigMaps containing:

```text
ca.crt
```

## Files

| File | Description |
|------|-------------|
| `providers.tf` | Configures Helm and Kubernetes providers |
| `main.tf` | Installs trust-manager Helm chart |
| `bundle.yaml` | Defines the CA distribution Bundle resource |
| `bundle.tf` | Applies the Bundle after CRD availability |
| `values.yaml` | Helm configuration values |

## Usage

```bash
terraform init
terraform apply
```

## Result

After this module completes:

- trust-manager is running in the `cert-manager` namespace.
- The internal `multipass-root-ca` certificate is automatically distributed.
- Applications can mount the generated ConfigMaps and trust certificates issued by the internal CA.

## Use Cases in This Lab

The distributed CA can be used by applications such as:

- Argo CD
- Dex
- Headlamp
- Other workloads requiring trust for internal HTTPS endpoints

## Next Step

Continue with application deployment managed by Argo CD or configure workloads to consume the distributed CA bundle.
