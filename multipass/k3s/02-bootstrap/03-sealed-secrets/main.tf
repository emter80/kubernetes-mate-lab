# Persistent key pair kept in Consul KV (stored there by init-key.sh), so SealedSecrets
# committed to Git stay decryptable after a cluster rebuild.
data "consul_keys" "sealed_secrets_key" {
  error_on_missing_keys = true

  key {
    name = "tls_crt"
    path = "topsecret/sealed-secrets/tls.crt"
  }

  key {
    name = "tls_key"
    path = "topsecret/sealed-secrets/tls.key"
  }
}

resource "kubernetes_namespace_v1" "sealed_secrets" {
  metadata {
    name = "sealed-secrets"
  }
}

resource "kubernetes_secret_v1" "sealed_secrets_key" {
  metadata {
    name      = "sealed-secrets-key"
    namespace = kubernetes_namespace_v1.sealed_secrets.metadata[0].name
    labels = {
      "sealedsecrets.bitnami.com/sealed-secrets-key" = "active"
    }
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = data.consul_keys.sealed_secrets_key.var.tls_crt
    "tls.key" = sensitive(data.consul_keys.sealed_secrets_key.var.tls_key)
  }
}

resource "helm_release" "sealed_secrets" {
  depends_on = [
    kubernetes_secret_v1.sealed_secrets_key
  ]

  name             = "sealed-secrets"
  namespace        = kubernetes_namespace_v1.sealed_secrets.metadata[0].name
  create_namespace = false

  repository = "https://bitnami.github.io/sealed-secrets"
  chart      = "sealed-secrets"

  version = "2.19.1"

  values = [
    file("${path.module}/values.yaml")
  ]
}
