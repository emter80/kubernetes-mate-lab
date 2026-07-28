resource "kubernetes_manifest" "multipass_root_ca" {
  depends_on = [
    kubernetes_manifest.selfsigned_issuer
  ]

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "multipass-root-ca"
      namespace = "cert-manager"
    }
    spec = {
      isCA       = true
      commonName = "multipass-root-ca"
      secretName = "multipass-root-ca"
      issuerRef = {
        name = "selfsigned"
        kind = "ClusterIssuer"
      }
    }
  }
}

resource "kubernetes_manifest" "multipass_ca_issuer" {
  depends_on = [
    kubernetes_manifest.multipass_root_ca
  ]
  
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "multipass-ca"
    }
    spec = {
      ca = {
        secretName = "multipass-root-ca"
      }
    }
  }
}