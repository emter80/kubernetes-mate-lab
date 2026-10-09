terraform {
  required_providers {
    consul = {
      source  = "hashicorp/consul"
      version = "2.23.0"
    }
  }
}

provider "consul" {
  address = "127.0.0.1:8500"
  scheme  = "http"
}
