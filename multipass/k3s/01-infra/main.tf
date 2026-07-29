terraform {
  required_providers {
    multipass = {
      source  = "todoroff/multipass"
      version = "1.7.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.3"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.38.0"
    }
  }
}

provider "multipass" {
}

resource "random_id" "mac_suffix" {
  count       = local.worker_count + 1
  byte_length = 3
}

resource "random_password" "k3s_token" {
  length           = 32
  special          = false
  override_special = ""
}

locals {
  worker_count = 2
  image        = "resolute"
  bridge_name  = "multipass"
  ip_prefix    = "10.20.0"
  ip_suffix    = 10
  master_ip    = "${local.ip_prefix}.${local.ip_suffix}"

  worker_ips = [
    for i in range(local.worker_count) :
    "${local.ip_prefix}.${local.ip_suffix + i + 1}"
  ]

  # Generate a safe list of MAC addresses for all nodes (master + workers)
  all_macs = [
    for i in range(local.worker_count + 1) : format("52:54:00:%s:%s:%s",
      substr(random_id.mac_suffix[i].hex, 0, 2),
      substr(random_id.mac_suffix[i].hex, 2, 2),
      substr(random_id.mac_suffix[i].hex, 4, 2)
    )
  ]

  # Master MAC is index 0
  mac_address = local.all_macs[0]

  # Workers MACs start from index 1 (index 0 is for master)
  worker_macs = [
    for i in range(local.worker_count) : local.all_macs[i + 1]
  ]

  k3s_token = random_password.k3s_token.result

  master_cloud_init = <<-EOT
    #cloud-config
    package_update: true
    package_upgrade: true

    write_files:
      - path: /etc/netplan/10-custom.yaml
        permissions: '0640'
        owner: root:root
        content: |
          network:
            version: 2
            ethernets:
              extra0:
                dhcp4: no
                match:
                  macaddress: "${local.mac_address}"
                addresses: ["${local.master_ip}/24"]

      - path: /usr/local/bin/k3s-kubectl-wrapper
        permissions: '0755'
        content: |
          #!/bin/sh
          sudo k3s kubectl "$@"

    runcmd:
      - netplan apply
      - curl -sfL https://get.k3s.io | K3S_TOKEN=${local.k3s_token} sh -s - server --cluster-init --node-ip=${local.master_ip} --flannel-iface=eth1
  EOT
}

#create control plane node
resource "multipass_instance" "k3s-master" {
  name       = "k3s-master"
  cpus       = 2
  memory     = "3G"
  disk       = "20G"
  image      = local.image
  cloud_init = local.master_cloud_init

  networks {
    name = local.bridge_name
    mode = "manual"
    mac  = local.mac_address
  }
}

# Create worker nodes
resource "multipass_instance" "k3s-worker" {
  count  = local.worker_count
  name   = "k3s-worker${count.index + 1}"
  cpus   = 1
  memory = "1280M"
  disk   = "20G"
  image  = local.image

  networks {
    name = local.bridge_name
    mode = "manual"
    mac  = local.worker_macs[count.index]
  }

  # Cloud-init script for workers
  cloud_init = <<-EOT
    #cloud-config
    package_update: true

    write_files:
      - path: /etc/netplan/10-custom.yaml
        permissions: '0640'
        owner: root:root
        content: |
          network:
            version: 2
            ethernets:
              extra0:
                dhcp4: no
                match:
                  macaddress: "${local.worker_macs[count.index]}"
                addresses: ["${local.worker_ips[count.index]}/24"]

    runcmd:
      - netplan apply
      - curl -sfL https://get.k3s.io | K3S_URL=https://${local.master_ip}:6443 K3S_TOKEN=${local.k3s_token} sh -s - --node-ip=${local.worker_ips[count.index]} --flannel-iface=eth1
  EOT

  # Wait for the master to be created before creating workers
  depends_on = [multipass_instance.k3s-master]
}

output "all_static_ips" {
  description = "List of static IP addresses (master first, followed by workers)"
  value       = concat([local.master_ip], local.worker_ips)
}

output "k3s_cluster_nodes" {
  description = "Map linking each node name to its static IP address"
  value = merge(
    { "master-node" = local.master_ip },
    { for i, ip in local.worker_ips : "worker-node${i + 1}" => ip }
  )
}
