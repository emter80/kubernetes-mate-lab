terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.2.1"
    }
    
    null = {
      source  = "hashicorp/null"
      version = "3.3.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "2.9.0"
    }

  }
}

provider "kubernetes" {
  config_path = pathexpand("~/.kube/config.multipass.k3s")
}
