resource "kubernetes_cluster_role_v1" "cert_manager_cainjector_configmaps" {
  metadata {
    name = "cert-manager-cainjector-configmaps"
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs = [
      "get",
      "list",
      "watch",
      "update",
      "patch"
    ]
  }
}


resource "kubernetes_cluster_role_binding_v1" "cert_manager_cainjector_configmaps" {
  metadata {
    name = "cert-manager-cainjector-configmaps"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.cert_manager_cainjector_configmaps.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "cert-manager-cainjector"
    namespace = "cert-manager"
  }
}
