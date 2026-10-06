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
