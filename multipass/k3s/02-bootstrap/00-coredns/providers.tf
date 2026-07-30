terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.2.1"
    }
  }
}

provider "kubernetes" {
  config_path = pathexpand("~/.kube/config.multipass.k3s")
}
