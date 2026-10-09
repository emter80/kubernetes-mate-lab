# Plain Secret manifests live in Consul KV: topsecret/apps/<app>.yaml -> 03-apps/<app>/sealed-<app>-secret.yaml
data "consul_key_prefix" "app_secrets" {
  path_prefix = "topsecret/apps/"
}

data "consul_keys" "sealing" {
  error_on_missing_keys = true

  key {
    name = "cert"
    path = "topsecret/sealed-secrets/tls.crt"
  }

  key {
    name = "key"
    path = "topsecret/sealed-secrets/tls.key"
  }
}

locals {
  hash_annotation = "mate-lab/source-hash"

  secrets = {
    for name, plain in data.consul_key_prefix.app_secrets.subkeys : trimsuffix(name, ".yaml") => {
      plain  = plain
      sealed = "../../03-apps/${trimsuffix(name, ".yaml")}/sealed-${trimsuffix(name, ".yaml")}-secret.yaml"
      # Keyed hash: changes when the plaintext or the sealing key changes; reveals nothing without the private key
      hash = sha256("${data.consul_keys.sealing.var.key}${plain}")
    }
    if endswith(name, ".yaml")
  }

  # Only secrets whose committed SealedSecret was produced from a different plaintext or key
  stale_secrets = toset([
    for app, secret in local.secrets : app
    if try(jsondecode(file("${path.module}/${secret.sealed}")).spec.template.metadata.annotations[local.hash_annotation], "") != secret.hash
  ])
}

resource "terraform_data" "seal_secret" {
  for_each = local.stale_secrets
  triggers_replace = [
    local.secrets[each.key].hash
  ]

  provisioner "local-exec" {
    interpreter = ["C:/Program Files/Git/bin/bash.exe", "-c"]

    environment = {
      PLAIN_SECRET = local.secrets[each.key].plain
      SEALING_CERT = data.consul_keys.sealing.var.cert
    }

    command = <<EOF
set -euo pipefail
cert_file="$(mktemp)"
trap 'rm -f -- "$cert_file"' EXIT
printf '%s' "$SEALING_CERT" > "$cert_file"
printf '%s' "$PLAIN_SECRET" | \
kubectl annotate --local -f - ${local.hash_annotation}="${local.secrets[each.key].hash}" -o yaml | \
kubeseal --cert "$cert_file" \
> "${path.module}/${local.secrets[each.key].sealed}"
EOF
  }
}

resource "terraform_data" "git_commit_sealed_secrets" {
  count = length(local.stale_secrets) > 0 ? 1 : 0

  depends_on = [
    terraform_data.seal_secret
  ]

  triggers_replace = [
    join(",", [for app in local.stale_secrets : local.secrets[app].hash])
  ]

  provisioner "local-exec" {
    interpreter = [
      "C:/Program Files/Git/bin/bash.exe",
      "-c"
    ]

    working_dir = path.module
    environment = {
      SEALED_SECRET_PATHS = join("\n", [for app in local.stale_secrets : local.secrets[app].sealed])
    }

    command = <<EOF
set -euo pipefail

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
    for app, secret in local.secrets :
    app => {
      source = "consul: topsecret/apps/${app}.yaml"
      target = secret.sealed
    }
  }
}

output "resealed_secrets" {
  description = "Secrets re-sealed in this run (plaintext or sealing key changed)"
  value       = local.stale_secrets
}
