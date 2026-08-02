resource "kubernetes_manifest" "multipass_root_ca_bundle" {
  manifest = yamldecode(
    file("${path.module}/bundle.yaml")
  )

  depends_on = [
    helm_release.trust_manager
  ]
}
