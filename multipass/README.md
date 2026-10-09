## Prerequisites

Before running this project, ensure you have the following software installed on your Windows11 host machine:

* **Multipass:** version  1.16.3 (or newer): https://canonical.com/multipass/install
* **Terraform:** version  1.15.8 (or newer): https://developer.hashicorp.com/terraform/install
* **Shell environment:** sh executable, e.g., Install Git Bash on Windows – must be added to your system PATH: https://gitforwindows.org/index.html
* **Consul:** a local Consul server available at `http://127.0.0.1:8500`: https://developer.hashicorp.com/consul/install
* **Docker Desktop:** required to run the local Consul container: https://www.docker.com/products/docker-desktop/
* **Virtual Switch:** setup a Hyper-V Virtual Switch named "multipass" (required for static IP assignment and bridge networking): https://dev.to/madalinignisca/how-to-permanent-private-ip-on-multipass-on-windows-with-hyper-v-14k6

## Start Local Consul

Start Consul before building or rebuilding the cluster. The Terraform backend stores state and locks in Consul; the local Docker volume preserves its data when the container is stopped or removed.

From Git Bash, start a new Consul container:

```bash
MSYS_NO_PATHCONV=1 docker run -d --name consul \
    -p 127.0.0.1:8500:8500 \
    -v consul-data:/consul/data \
    hashicorp/consul:2.0.4 \
    agent -server -bootstrap-expect=1 -ui -client=0.0.0.0 -data-dir=/consul/data
```

If the `consul` container already exists, start it instead:

```bash
docker start consul
```

Verify that Consul has elected a leader:

```bash
curl http://127.0.0.1:8500/v1/status/leader
```

The Consul UI is available at <http://127.0.0.1:8500/ui/>. This single-node setup is for local development, not production. Do not run `--clean` while Terraform is operating; it deletes local state and the Consul `terraform/` KV prefix but does not destroy managed infrastructure.

## Secrets in Consul

Plain secrets and the Sealed Secrets key pair are stored in Consul KV under `topsecret/` (never in Git):

| Key | Content |
|-----|---------|
| `topsecret/sealed-secrets/tls.crt`, `tls.key` | Sealed Secrets controller key pair; created automatically on the first build |
| `topsecret/argocd/github-oauth-secret.yaml` | Argo CD GitHub OAuth Secret manifest (required) |
| `topsecret/apps/<app>.yaml` | Secret manifests sealed into `03-apps/<app>/sealed-<app>-secret.yaml` |

Upload a secret (templates are in `02-bootstrap/07-secrets/templates/`):

```bash
curl -X PUT --data-binary @github-oauth-secret.yaml http://127.0.0.1:8500/v1/kv/topsecret/argocd/github-oauth-secret.yaml
```

`--rebuild`, `--destroy` and `--clean` remove only the `terraform/` prefix; `topsecret/` is kept. Consul runs on the same host, so keep an encrypted backup elsewhere:

```bash
./main_bootstrap.sh --backup-secrets
./main_bootstrap.sh --restore-secrets ~/mate-lab-topsecret-<date>.enc
```

Run `--backup-secrets` again after any change under `topsecret/` (new app secret, rotated OAuth secret, new CA).

## Disaster Recovery

Everything under `topsecret/` is a credential, not data: it can always be recreated by rotation. A backup only saves time. Pick the first scenario that matches.

### 1. Consul lost, backup available

```bash
docker rm -f consul 2>/dev/null || true
MSYS_NO_PATHCONV=1 docker run -d --name consul -p 127.0.0.1:8500:8500 -v consul-data:/consul/data \
    hashicorp/consul:2.0.4 agent -server -bootstrap-expect=1 -ui -client=0.0.0.0 -data-dir=/consul/data
./main_bootstrap.sh --restore-secrets ~/mate-lab-topsecret-<date>.enc
```

Nothing changes for the cluster, Git or the Windows trust store. Terraform state lived in the same Consul, so the next infrastructure change needs `./main_bootstrap.sh --rebuild`.

### 2. Consul and backup lost, cluster still running

Start a new Consul container (as above), then copy the secrets back from the cluster:

```bash
./main_bootstrap.sh --recover-secrets
./main_bootstrap.sh --backup-secrets
```

It restores the Sealed Secrets key, the root CA (only if valid for more than a year; otherwise a new one is generated) and the plain Secret manifests of Argo CD and every app with a `sealed-*-secret.yaml`. Keys already in Consul are never overwritten. Terraform state is not needed: the next `--rebuild` starts from scratch.

### 3. Everything lost (Consul, backup and cluster)

1. Start a new Consul container (as above).
2. Rotate the credentials that cannot be read back:
   - GitHub → Settings → Developer settings → OAuth Apps → **Generate a new client secret** for the Argo CD app and the Dex app.
   - Choose a new Dex ↔ Headlamp static client secret (the same value in both files).
3. Fill in the templates from `02-bootstrap/07-secrets/templates/` outside the repository and upload them:

   ```bash
   curl -X PUT --data-binary @argocd-github-oauth-secret.yaml http://127.0.0.1:8500/v1/kv/topsecret/argocd/github-oauth-secret.yaml
   curl -X PUT --data-binary @dex-secret.yaml http://127.0.0.1:8500/v1/kv/topsecret/apps/dex.yaml
   curl -X PUT --data-binary @headlamp-secret.yaml http://127.0.0.1:8500/v1/kv/topsecret/apps/headlamp.yaml
   ```

4. `./main_bootstrap.sh --rebuild`: a new Sealed Secrets key and root CA are generated, all secrets are re-sealed and pushed.
5. `./install-root-ca.sh`: trust the new CA and remove the old ones.
6. `./main_bootstrap.sh --backup-secrets`, and delete the plaintext files used in step 3.

### Leaked backup or Consul data

Follow scenario 3 to rotate everything: the old Sealed Secrets key could decrypt the SealedSecrets in Git history, and the old CA could sign certificates trusted by your browser. Delete `topsecret/sealed-secrets/` and `topsecret/root-ca/` in Consul first so new ones are generated.

## Install K3s Cluster
### Task 1 - Build the cluster
Fork the repo: https://github.com/emter80/kubernetes-mate-lab.git
and clone to <base_dir>
```bash
cd <base_dir>
cd kubernetes-mate-lab/multipass/k3s/
./main_bootstrap.sh --build
```

### Task 2 - Trust the cluster Root CA

After the cluster bootstrap completes, run this from Git Bash in `multipass/k3s`:

```bash
cd <base_dir>
cd kubernetes-mate-lab/multipass/k3s/
./install-root-ca.sh
```

The script verifies the generated public CA certificate and, after you type `YES`, imports it into the current Windows user's `Root` certificate store. Windows may show an additional trust warning. No administrator privileges are required, and the CA private key is never imported.

## Destroy K3s Cluster

### Task 1 - Destroy the cluster
```bash
cd <base_dir>
cd kubernetes-mate-lab/multipass/k3s/
./main_bootstrap.sh --destroy
```
