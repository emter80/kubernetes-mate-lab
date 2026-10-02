locals {
  secret_files = {
    for file in fileset("${path.module}/topsecret", "plain-*.yaml") :
    replace(replace(file, "plain-", ""), "-secret.yaml", "") => file
  }

  sealed_secret_paths = [
    for app in keys(local.secret_files) :
    "../../03-apps/${app}/sealed-${app}-secret.yaml"
  ]
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

    working_dir = path.module
    environment = {
      SEALED_SECRET_PATHS = join("\n", local.sealed_secret_paths)
    }

    command = <<EOF
set -euo pipefail

if [[ -z "$${SEALED_SECRET_PATHS}" ]]; then
  echo "No plaintext secrets found; skipping Git publication."
  exit 0
fi

mapfile -t sealed_paths <<< "$${SEALED_SECRET_PATHS}"
git add -- "$${sealed_paths[@]}"

if git diff --cached --quiet -- "$${sealed_paths[@]}"; then
  echo "No sealed-secret changes to commit."
  exit 0
fi

upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}')
git fetch --quiet
ahead=$(git rev-list --count "$${upstream}..HEAD")
behind=$(git rev-list --count "HEAD..$${upstream}")

if [[ "$${ahead}" -ne 0 || "$${behind}" -ne 0 ]]; then
  echo "Local branch differs from its upstream; synchronize it before publishing secrets." >&2
  exit 1
fi

current_date=$(date "+%Y-%m-%d %H:%M:%S")
git commit --only -m "Updated app sealed secrets - $current_date" -- "$${sealed_paths[@]}"
git push
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
    files = [
      for app in keys(local.secret_files) :
      "03-apps/${app}/sealed-${app}-secret.yaml"
    ]
  }
}
