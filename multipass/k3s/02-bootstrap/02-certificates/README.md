# Certificates

This module configures the certificate infrastructure for the K3s cluster using cert-manager.

## Purpose

The module installs a private, persistent Certificate Authority (CA) that is used to issue TLS certificates for services running inside the cluster. The CA is stored in Consul KV, so it survives cluster rebuilds and the Windows host has to trust it only once.

## What this module does

- `init-root-ca.sh` (run by `bootstrap.sh` before Terraform) ensures the CA exists in Consul KV under `topsecret/root-ca/`; on the first build it generates one (ECDSA P-256, valid 10 years, `CN=multipass-root-ca`)
- Reads the CA from Consul and stores it in the `cert-manager/multipass-root-ca` Secret (`tls.crt`, `tls.key`, `ca.crt`)
- Creates a CA-based `ClusterIssuer` (`multipass-ca`) that signs application certificates
- Grants the `cert-manager-cainjector` ServiceAccount permission to update ConfigMaps

## Certificate Hierarchy

```text
Consul KV topsecret/root-ca/
        │
        ▼
Secret cert-manager/multipass-root-ca
        │
        ▼
multipass-ca (CA ClusterIssuer)
        │
        ▼
Application TLS Certificates (renewed automatically by cert-manager)
```

## Installed Components

| Resource | Description |
|----------|-------------|
| `Secret/multipass-root-ca` | Root CA key pair restored from Consul |
| `ClusterIssuer/multipass-ca` | CA issuer used to sign application certificates |
| `ClusterRole` | Allows cert-manager-cainjector to update ConfigMaps |
| `ClusterRoleBinding` | Assigns the ClusterRole to the cert-manager-cainjector ServiceAccount |

## Files

| File | Description |
|------|-------------|
| `init-root-ca.sh` | Generates the root CA into Consul KV if it does not exist |
| `providers.tf` | Configures the Kubernetes and Consul providers |
| `ca.tf` | Restores the root CA Secret and creates the CA ClusterIssuer |
| `rbac.tf` | Grants additional permissions to cert-manager-cainjector |

## Trusting the CA on Windows

Run `install-root-ca.sh` once after the first build with this CA. It also offers to remove stale `multipass-root-ca` certificates left by earlier builds. Rotating the CA means deleting `topsecret/root-ca/` in Consul, rebuilding, and running `install-root-ca.sh` again.

## Result

After this module completes, the cluster contains a private Certificate Authority that can issue trusted TLS certificates for applications such as Traefik, Argo CD, Headlamp, and Dex.
