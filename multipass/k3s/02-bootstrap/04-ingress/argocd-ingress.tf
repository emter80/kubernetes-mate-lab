resource "kubernetes_manifest" "argocd_ingressroute" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"

    metadata = {
      name      = "argocd"
      namespace = "argocd"
    }

    spec = {
      entryPoints = [
        "websecure"
      ]

      routes = [
        {
          match = "Host(`argocd.multipass.k3s`)"
          kind = "Rule"

          services = [
            {
              name = "argocd-server"
              port = 80
            }
          ]
        }
      ]

      tls = {
        secretName = "argocd-tls"
      }
    }
  }
}