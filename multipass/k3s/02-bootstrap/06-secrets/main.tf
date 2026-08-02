locals {
  secret_files = {
    for file in fileset("${path.module}/topsecret", "plain-*.yaml") :
    replace(replace(file, "plain-", ""), "-secret.yaml", "") => file
  }
}


resource "terraform_data" "seal_secret" {

  for_each = local.secret_files

  triggers_replace = [
    filesha256("${path.module}/topsecret/${each.value}")
  ]

  provisioner "local-exec" {
    interpreter = ["C:/Program Files/Git/bin/bash.exe", "-c"]

    command = <<EOF
kubeseal \
--kubeconfig ~/.kube/config.multipass.k3s \
--controller-name sealed-secrets-controller \
--controller-namespace sealed-secrets \
< ${path.module}/topsecret/${each.value} \
> ${path.module}/../../03-apps/${each.key}/sealed-${each.key}-secret.yaml
EOF

  }
}

resource "terraform_data" "git_commit_sealed_secrets" {

  depends_on = [
    terraform_data.seal_secret
  ]

  triggers_replace = [
    join(",", [
      for file in local.secret_files :
      filesha256("${path.module}/topsecret/${file}")
    ])
  ]

  provisioner "local-exec" {

    interpreter = [
      "C:/Program Files/Git/bin/bash.exe",
      "-c"
    ]

    command = <<EOF
git add ../../03-apps/*/sealed-*-secret.yaml

if git diff --cached --quiet; then
  echo "No changes to commit"
else
  git commit -m "Update sealed secrets"
fi
EOF

  }
}

output "sealed_secret_mapping" {
  value = {
    for app, file in local.secret_files :
    app => {
      source = "topsecret/${file}"
      target = "../../03-apps/${app}/sealed-${app}-secret.yaml"
    }
  }
}

output "sealed_secret_git_files" {
  value = [
    for app in keys(local.secret_files) :
    "../../03-apps/${app}/sealed-${app}-secret.yaml"
  ]
}

output "sealed_secret_commit_info" {
  value = {
    message = "Sealed secrets generated and committed"
    files   = [
      for app in keys(local.secret_files) :
      "03-apps/${app}/sealed-${app}-secret.yaml"
    ]
  }
}
