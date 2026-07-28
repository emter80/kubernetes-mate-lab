terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }
  }

  required_version = ">= 1.6.0"
}

provider "kubernetes" {
  config_path = pathexpand("~/.kube/config.multipass.k3s")
}
