data "consul_keys" "secrets" {
  error_on_missing_keys = true

  key {
    name = "sealing_cert"
    path = "topsecret/sealed-secrets/tls.crt"
  }

  key {
    name = "sealing_key"
    path = "topsecret/sealed-secrets/tls.key"
  }

  key {
    name = "github_oauth_secret"
    path = "topsecret/argocd/github-oauth-secret.yaml"
  }
}

locals {
  sealed_github_oauth_secret = "${path.module}/sealed-argocd-github-oauth-secret.yaml"
  hash_annotation            = "mate-lab/source-hash"

  # Keyed hash: changes when the plaintext or the sealing key changes; reveals nothing without the private key
  github_oauth_secret_hash = sha256("${data.consul_keys.secrets.var.sealing_key}${data.consul_keys.secrets.var.github_oauth_secret}")

  # Re-seal only when the committed SealedSecret was produced from a different plaintext or key
  reseal_github_oauth_secret = try(jsondecode(file(local.sealed_github_oauth_secret)).spec.template.metadata.annotations[local.hash_annotation], "") != local.github_oauth_secret_hash
}

resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "terraform_data" "seal_argocd_github_oauth_secret" {
  count = local.reseal_github_oauth_secret ? 1 : 0

  triggers_replace = [
    local.github_oauth_secret_hash
  ]

  provisioner "local-exec" {
    interpreter = [
      "C:/Program Files/Git/bin/bash.exe",
      "-c"
    ]

    environment = {
      PLAIN_SECRET = data.consul_keys.secrets.var.github_oauth_secret
      SEALING_CERT = data.consul_keys.secrets.var.sealing_cert
    }

    command = <<EOF
set -euo pipefail
cert_file="$(mktemp)"
trap 'rm -f -- "$cert_file"' EXIT
printf '%s' "$SEALING_CERT" > "$cert_file"
printf '%s' "$PLAIN_SECRET" | \
kubectl annotate --local -f - ${local.hash_annotation}="${local.github_oauth_secret_hash}" -o yaml | \
kubeseal --cert "$cert_file" \
> "${local.sealed_github_oauth_secret}"
EOF
  }
}

resource "terraform_data" "git_commit_argocd_github_oauth_secret" {
  count = local.reseal_github_oauth_secret ? 1 : 0

  depends_on = [
    terraform_data.seal_argocd_github_oauth_secret
  ]

  triggers_replace = [
    local.github_oauth_secret_hash
  ]

  provisioner "local-exec" {
    interpreter = [
      "C:/Program Files/Git/bin/bash.exe",
      "-c"
    ]

    command = <<EOF
set -e
sealed_secret_path="${local.sealed_github_oauth_secret}"
git add -- "$sealed_secret_path"

if git diff --cached --quiet -- "$sealed_secret_path"; then
  echo "No changes to commit"
else
  CURRENT_DATE=$(date "+%Y-%m-%d %H:%M:%S")
  git commit --only -m "Update Argo CD GitHub OAuth sealed secret - $CURRENT_DATE" -- "$sealed_secret_path"
  git push
fi
EOF
  }
}

resource "terraform_data" "apply_argocd_github_oauth_secret" {
  depends_on = [
    kubernetes_namespace_v1.argocd,
    terraform_data.seal_argocd_github_oauth_secret
  ]

  triggers_replace = [
    local.github_oauth_secret_hash
  ]

  provisioner "local-exec" {
    interpreter = [
      "C:/Program Files/Git/bin/bash.exe",
      "-c"
    ]

    command = <<EOF
kubectl apply \
--kubeconfig ~/.kube/config.multipass.k3s \
-f ${local.sealed_github_oauth_secret}
EOF
  }
}

resource "helm_release" "argocd" {
  depends_on = [
    terraform_data.apply_argocd_github_oauth_secret
  ]

  name             = "argocd"
  namespace        = kubernetes_namespace_v1.argocd.metadata[0].name
  create_namespace = false
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "10.2.1"
  values = [
    yamlencode({
      # Requests tell the scheduler how much each component needs (measured with kubectl top
      # plus headroom); memory limits cap leaks. No CPU limits: CPU shortage only throttles.
      controller = {
        resources = {
          requests = { cpu = "100m", memory = "256Mi" }
          limits   = { memory = "512Mi" }
        }
      }

      repoServer = {
        resources = {
          requests = { cpu = "50m", memory = "128Mi" }
          limits   = { memory = "384Mi" }
        }
      }

      server = {
        extraArgs = [
          "--insecure"
        ]
        resources = {
          requests = { cpu = "20m", memory = "64Mi" }
          limits   = { memory = "128Mi" }
        }
      }

      dex = {
        resources = {
          requests = { cpu = "10m", memory = "64Mi" }
          limits   = { memory = "128Mi" }
        }
      }

      redis = {
        resources = {
          requests = { cpu = "10m", memory = "32Mi" }
          limits   = { memory = "64Mi" }
        }
      }

      applicationSet = {
        resources = {
          requests = { cpu = "10m", memory = "48Mi" }
          limits   = { memory = "128Mi" }
        }
      }

      notifications = {
        resources = {
          requests = { cpu = "10m", memory = "48Mi" }
          limits   = { memory = "96Mi" }
        }
      }

      configs = {
        cm = {
          url          = "https://argocd.multipass.k3s"
          "dex.config" = <<-EOT
            connectors:
            - type: github
              id: github
              name: GitHub
              config:
                clientID: $argocd-github-oauth-secret:clientID
                clientSecret: $argocd-github-oauth-secret:clientSecret
          EOT
        }

        rbac = {
          "policy.default" = "role:readonly"
          "policy.csv"     = <<-EOT
            g, emter80, role:admin
            g, emter80@gmail.com, role:admin
          EOT
          scopes           = "[groups, email, preferred_username]"
        }
      }
    })
  ]
}
