# Secrets

This module automates the management of Kubernetes secrets using **Bitnami Sealed Secrets**.

## Purpose

The module converts plain Kubernetes `Secret` manifests stored in Consul KV into encrypted `SealedSecret` resources that are safe to store in Git. A secret is re-sealed only when its plaintext or the sealing key changes, so a regular cluster rebuild produces no Git commits.

## What this module does

- Reads plain Secret manifests from Consul KV prefix `topsecret/apps/`
- Reads the persistent Sealed Secrets key pair from `topsecret/sealed-secrets/`
- Compares a keyed hash (`sha256(private key + plaintext)`) with the `mate-lab/source-hash` annotation of the committed `SealedSecret`
- Re-seals offline with `kubeseal --cert` only the secrets whose hash differs (changed plaintext, new key, or missing file)
- Stores generated manifests under `03-apps/<application>/`
- Commits and pushes only the re-sealed files

Before publishing, the current branch must be synchronized with its upstream. Other staged files are not included in the Sealed Secret commit.

## Directory Structure

### Input (Consul KV)

```text
topsecret/
├── sealed-secrets/
│   ├── tls.crt          # Sealed Secrets controller key pair (init-key.sh)
│   └── tls.key
├── argocd/
│   └── github-oauth-secret.yaml   # used by 04-argocd
└── apps/
    ├── dex.yaml
    ├── headlamp.yaml
    └── <app>.yaml
```

### Output (Git)

```text
03-apps/
├── dex/
│   └── sealed-dex-secret.yaml
├── headlamp/
│   └── sealed-headlamp-secret.yaml
└── ...
```

## Adding or Changing a Secret

Start from a template in `templates/`, fill in the values outside the repository, and upload it:

```bash
curl -X PUT --data-binary @dex-secret.yaml http://127.0.0.1:8500/v1/kv/topsecret/apps/dex.yaml
```

The next `main_bootstrap.sh --build` / `--rebuild` (or `terraform apply` in this module) re-seals it.

## Backup

The Consul container runs on the same host as the cluster. Keep an encrypted copy elsewhere:

```bash
./main_bootstrap.sh --backup-secrets
./main_bootstrap.sh --restore-secrets ~/mate-lab-topsecret-<date>.enc
```

## Requirements

- Consul KV reachable at `http://127.0.0.1:8500` with the `topsecret/` prefix populated
- `kubeseal` and `kubectl` installed locally (sealing runs offline, no cluster access needed)
- Git configured with permission to push to the remote repository

## Terraform Resources

| Resource | Description |
|----------|-------------|
| `data.consul_key_prefix.app_secrets` | Reads plain Secret manifests from `topsecret/apps/` |
| `data.consul_keys.sealing` | Reads the Sealed Secrets key pair |
| `terraform_data.seal_secret` | Re-seals stale secrets using `kubeseal` |
| `terraform_data.git_commit_sealed_secrets` | Commits and pushes re-sealed secrets |

## Outputs

- `sealed_secret_mapping` - Consul source to Git target mapping
- `resealed_secrets` - secrets re-sealed in this run

## Security

Only encrypted `SealedSecret` manifests are stored in Git. Plaintext manifests and the private key live in Consul KV (local, no ACL) and in the encrypted backup file. The hash annotation includes the private key, so it reveals nothing about the plaintext.
