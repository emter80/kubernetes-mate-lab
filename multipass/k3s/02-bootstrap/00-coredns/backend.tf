terraform {
  backend "consul" {
    address = "127.0.0.1:8500"
    scheme  = "http"
    path    = "terraform/02-bootstrap/00-coredns/terraform.tfstate"
  }
}
