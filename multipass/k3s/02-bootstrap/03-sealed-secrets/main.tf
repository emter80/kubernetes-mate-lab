resource "helm_release" "sealed_secrets" {
  name             = "sealed-secrets"
  namespace        = "sealed-secrets"
  create_namespace = true

  repository = "https://bitnami-labs.github.io/sealed-secrets"
  chart      = "sealed-secrets"

  version = "2.19.1"

  values = [
    file("${path.module}/values.yaml")
  ]
}
