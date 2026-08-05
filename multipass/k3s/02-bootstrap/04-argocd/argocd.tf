locals {
  argocd_github_oauth_secret = "${path.module}/topsecret/plain-argocd-github-oauth-secret.yaml"
}


resource "kubernetes_namespace_v1" "argocd" {

  metadata {
    name = "argocd"
  }
}



resource "terraform_data" "seal_argocd_github_oauth_secret" {

  depends_on = [
    kubernetes_namespace_v1.argocd
  ]


  triggers_replace = [
    filesha256(local.argocd_github_oauth_secret)
  ]


  provisioner "local-exec" {

    interpreter = [
      "C:/Program Files/Git/bin/bash.exe",
      "-c"
    ]


    command = <<EOF
kubeseal \
--kubeconfig ~/.kube/config.multipass.k3s \
--controller-name sealed-secrets-controller \
--controller-namespace sealed-secrets \
< ${local.argocd_github_oauth_secret} \
> ${path.module}/sealed-argocd-github-oauth-secret.yaml
EOF

  }
}



resource "terraform_data" "git_commit_argocd_github_oauth_secret" {

  depends_on = [
    terraform_data.seal_argocd_github_oauth_secret
  ]


  triggers_replace = [
    filesha256(local.argocd_github_oauth_secret)
  ]


  provisioner "local-exec" {

    interpreter = [
      "C:/Program Files/Git/bin/bash.exe",
      "-c"
    ]


    command = <<EOF
git add ${path.module}/sealed-argocd-github-oauth-secret.yaml

if git diff --cached --quiet; then
  echo "No changes to commit"
else
  CURRENT_DATE=$(date "+%Y-%m-%d %H:%M:%S")
  git commit -m "Update Argo CD GitHub OAuth sealed secret - $CURRENT_DATE"
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
    filesha256(local.argocd_github_oauth_secret)
  ]


  provisioner "local-exec" {

    interpreter = [
      "C:/Program Files/Git/bin/bash.exe",
      "-c"
    ]


    command = <<EOF
kubectl apply \
--kubeconfig ~/.kube/config.multipass.k3s \
-f ${path.module}/sealed-argocd-github-oauth-secret.yaml
EOF

  }
}



resource "helm_release" "argocd" {

  depends_on = [
    terraform_data.apply_argocd_github_oauth_secret
  ]


  name = "argocd"


  namespace = kubernetes_namespace_v1.argocd.metadata[0].name


  create_namespace = false


  repository = "https://argoproj.github.io/argo-helm"


  chart = "argo-cd"


  version = "10.2.1"



  values = [
    yamlencode({

      server = {

        extraArgs = [
          "--insecure"
        ]

      }



      configs = {

        cm = {

          url = "https://argocd.multipass.k3s"



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


          "policy.csv" = <<-EOT
            g, emter80, role:admin
          EOT


          scopes = "[groups,email]"

        }

      }

    })
  ]
}
