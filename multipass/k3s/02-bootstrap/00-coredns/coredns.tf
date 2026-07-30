data "kubernetes_config_map_v1" "coredns" {
  metadata {
    name      = "coredns"
    namespace = "kube-system"
  }
}

resource "kubernetes_config_map_v1_data" "coredns" {
  metadata {
    name      = "coredns"
    namespace = "kube-system"
  }

  data = {
    Corefile = replace(
      data.kubernetes_config_map_v1.coredns.data["Corefile"],
      "forward . /etc/resolv.conf",
      "forward . 1.1.1.1 8.8.8.8"
    )
  }

  force = true
}
