resource "kubernetes_manifest" "argocd_certificate" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"

    metadata = {
      name      = "argocd-tls"
      namespace = "argocd"
    }

    spec = {
      secretName = "argocd-tls"
      dnsNames = [
        "argocd.multipass.k3s"
      ]

      issuerRef = {
        name = "multipass-ca"
        kind = "ClusterIssuer"
      }
    }
  }
}
