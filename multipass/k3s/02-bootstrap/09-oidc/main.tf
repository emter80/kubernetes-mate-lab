data "kubernetes_secret_v1" "multipass_root_ca" {
  metadata {
    name      = "multipass-root-ca"
    namespace = "cert-manager"
  }
}


resource "local_file" "multipass_root_ca_crt" {
  content  = data.kubernetes_secret_v1.multipass_root_ca.data["ca.crt"]
  filename = "${path.module}/multipass-root-ca.crt"
}


resource "null_resource" "k3s_oidc" {

  depends_on = [
    local_file.multipass_root_ca_crt
  ]

  provisioner "local-exec" {

    interpreter = ["C:/Program Files/Git/bin/bash.exe", "-c"]

    command = <<EOF
multipass transfer \
  "${local_file.multipass_root_ca_crt.filename}" \
  k3s-master:/tmp/multipass-root-ca.crt

multipass transfer \
  "${path.module}/config.yaml" \
  k3s-master:/tmp/k3s-config.yaml
EOF
  }


  provisioner "local-exec" {

    interpreter = ["C:/Program Files/Git/bin/bash.exe", "-c"]

    command = <<EOF
multipass exec k3s-master -- bash -c '
sudo mkdir -p /etc/rancher/k3s
sudo cp /tmp/multipass-root-ca.crt /etc/rancher/k3s/multipass-root-ca.crt
sudo cp /tmp/k3s-config.yaml /etc/rancher/k3s/config.yaml
sudo chmod 644 /etc/rancher/k3s/multipass-root-ca.crt
sudo systemctl restart k3s
'
EOF
  }
}
