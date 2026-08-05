terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "3.2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.2.1"
    }
  }
}

provider "helm" {
  kubernetes = {
    config_path = pathexpand("~/.kube/config.multipass.k3s")
  }
}


provider "kubernetes" {
  config_path = pathexpand("~/.kube/config.multipass.k3s")
}
