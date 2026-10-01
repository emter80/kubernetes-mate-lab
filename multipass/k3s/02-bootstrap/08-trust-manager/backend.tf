terraform {
  backend "consul" {
    address = "127.0.0.1:8500"
    scheme  = "http"
    path    = "terraform/02-bootstrap/08-trust-manager/terraform.tfstate"
  }
}