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
            repoURL  = "https://github.com/emter80/kubernetes-mate-lab.git"
            revision = "main"

            files = [
              {
                path = "multipass/k3s/03-apps/applications/**/app.yaml"
              },
              {
                path = "multipass/k3s/03-apps/platform/**/app.yaml"
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

          - repoURL: {{.repoURL}}
            chart: {{.chart}}
            targetRevision: {{.targetRevision}}
            helm:
              valueFiles:
                - $values/{{.valuesFile}}

          - repoURL: https://github.com/emter80/kubernetes-mate-lab.git
            targetRevision: main
            ref: values

          {{- else }}

          - repoURL: {{.repoURL}}
            targetRevision: {{.targetRevision}}
            path: {{.kustomizePath}}

          {{- end }}
      EOT
    }
  }
}
