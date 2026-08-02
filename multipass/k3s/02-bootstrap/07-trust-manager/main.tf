resource "helm_release" "trust_manager" {
  name             = "trust-manager"
  namespace        = "cert-manager"
  create_namespace = false

  repository = "https://charts.jetstack.io"
  chart      = "trust-manager"

  values = [
    file("${path.module}/values.yaml")
  ]

  wait = true
}
