resource "terraform_data" "apply_bundle" {
  depends_on = [
    helm_release.trust_manager
  ]

  triggers_replace = [
    filesha256("${path.module}/bundle.yaml")
  ]

  provisioner "local-exec" {
    interpreter = ["C:/Program Files/Git/bin/bash.exe", "-c"]
    command     = <<EOF
until kubectl --kubeconfig ~/.kube/config.multipass.k3s get crd bundles.trust.cert-manager.io &>/dev/null; do
  echo "Waiting for trust-manager CRD..."
  sleep 2
done
kubectl --kubeconfig ~/.kube/config.multipass.k3s apply -f ${path.module}/bundle.yaml
EOF
  }
}
