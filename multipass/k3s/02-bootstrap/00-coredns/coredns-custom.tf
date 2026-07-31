resource "kubernetes_config_map_v1" "coredns_custom" {
  metadata {
    name      = "coredns-custom"
    namespace = "kube-system"
  }

  data = {
    "dex.override" = <<-EOF
      rewrite name dex.multipass.k3s traefik.kube-system.svc.cluster.local
    EOF
  }
}
