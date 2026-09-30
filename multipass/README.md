## Prerequisites

Before running this project, ensure you have the following software installed on your Windows11 host machine:

* **Multipass:** version  1.16.3 (or newer)
* **Terraform:** version  1.15.8 (or newer)
* **Shell environment:** sh executable, e.g., Install Git Bash on Windows – must be added to your system PATH
* **Virtual Switch:** setup a Hyper-V Virtual Switch named "multipass" (required for static IP assignment and bridge networking)

    [See details on how to setup Virtual Switch](https://dev.to/madalinignisca/how-to-permanent-private-ip-on-multipass-on-windows-with-hyper-v-14k6)

## Install K3s Cluster
### Task 1 - Build the cluster
```bash
cd <base_dir>
git clone https://github.com/emter80/kubernetes-mate-lab.git
cd kubernetes-mate-lab/multipass/k3s/
./main_bootstrap.sh --build
```

### Task 2 - Trust the cluster Root CA

After the cluster bootstrap completes, run this from Git Bash in `multipass/k3s`:

```bash
./install-root-ca.sh
```

The script verifies the generated public CA certificate and, after you type `YES`, imports it into the current Windows user's `Root` certificate store. Windows may show an additional trust warning. No administrator privileges are required, and the CA private key is never imported.

## Destroy K3s Cluster

### Task 1 - Destroy the cluster
```bash
cd <base_dir>
git clone https://github.com/emter80/kubernetes-mate-lab.git
cd kubernetes-mate-lab/multipass/k3s/
./main_bootstrap.sh --destroy
```
