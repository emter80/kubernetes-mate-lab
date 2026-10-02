resource "kubernetes_manifest" "platform_applicationset" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "ApplicationSet"

    metadata = {
      name      = "platform-apps"
      namespace = "argocd"
    }

    spec = {
      goTemplate = true

      goTemplateOptions = [
        "missingkey=default"
      ]

      generators = [
        {
          git = {
            repoURL  = var.git_repo_url
            revision = var.git_revision

            files = [
              {
                path = "multipass/k3s/03-apps/**/app.yaml"
              }
            ]
          }
        }
      ]

      template = {
        metadata = {
          name = "{{.name}}"
        }

        spec = {
          project = "default"

          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = "{{.namespace}}"
          }

          syncPolicy = {
            automated = {
              prune    = true
              selfHeal = true
            }

            syncOptions = [
              "CreateNamespace=true"
            ]
          }
        }
      }

      templatePatch = <<-EOT
spec:
  sources:

  {{- if .chart }}
  - repoURL: {{ .repoURL }}
    chart: {{ .chart }}
    targetRevision: {{ .targetRevision }}
    helm:
      valueFiles:
        - $values/{{ .valuesFile }}

  - repoURL: ${var.git_repo_url}
    targetRevision: ${var.git_revision}
    ref: values
  {{- end }}

  {{- if .kustomizePath }}
  - repoURL: ${var.git_repo_url}
    targetRevision: ${var.git_revision}
    path: {{ .kustomizePath }}
  {{- end }}
      EOT
    }
  }
}
