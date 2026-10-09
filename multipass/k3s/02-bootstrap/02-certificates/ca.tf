# Persistent root CA kept in Consul KV (stored there by init-root-ca.sh), so the CA trusted
# on the Windows host stays valid after a cluster rebuild.
data "consul_keys" "root_ca" {
  error_on_missing_keys = true

  key {
    name = "tls_crt"
    path = "topsecret/root-ca/tls.crt"
  }

  key {
    name = "tls_key"
    path = "topsecret/root-ca/tls.key"
  }
}

resource "kubernetes_secret_v1" "multipass_root_ca" {
  metadata {
    name      = "multipass-root-ca"
    namespace = "cert-manager"
  }

  type = "kubernetes.io/tls"

  # ca.crt is consumed by the trust-manager Bundle (08) and the API server OIDC config (09)
  data = {
    "tls.crt" = data.consul_keys.root_ca.var.tls_crt
    "tls.key" = sensitive(data.consul_keys.root_ca.var.tls_key)
    "ca.crt"  = data.consul_keys.root_ca.var.tls_crt
  }
}

resource "kubernetes_manifest" "multipass_ca_issuer" {
  depends_on = [
    kubernetes_secret_v1.multipass_root_ca
  ]

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "multipass-ca"
    }
    spec = {
      ca = {
        secretName = kubernetes_secret_v1.multipass_root_ca.metadata[0].name
      }
    }
  }
}
